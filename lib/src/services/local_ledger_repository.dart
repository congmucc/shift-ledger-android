import 'dart:convert';
import 'dart:io';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';
import 'backup_service.dart';

class LoadedLedgerData {
  const LoadedLedgerData({
    required this.snapshot,
    this.diagnostics = const BackupDecodeDiagnostics(),
  });

  final LedgerSnapshot snapshot;
  final BackupDecodeDiagnostics diagnostics;
}

class ExternalSaveRequest {
  const ExternalSaveRequest({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class DirectorySaveRequest {
  const DirectorySaveRequest({
    required this.directoryUri,
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final String directoryUri;
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

typedef ExternalFileSaver =
    Future<String?> Function(ExternalSaveRequest request);
typedef ExternalFilePicker = Future<String?> Function();
typedef DirectoryPickerSupportChecker = Future<bool> Function();
typedef ExternalDirectoryPicker = Future<String?> Function();
typedef ExternalDirectorySaver =
    Future<String?> Function(DirectorySaveRequest request);
typedef RootDirectoryProvider = Future<Directory> Function();

class LocalLedgerRepository {
  LocalLedgerRepository({
    Directory? directory,
    FlutterSecureStorage? secureStorage,
    ExternalFileSaver? externalSaver,
    ExternalFilePicker? externalPicker,
    DirectoryPickerSupportChecker? directorySupportChecker,
    ExternalDirectoryPicker? directoryPicker,
    ExternalDirectorySaver? directorySaver,
    RootDirectoryProvider? rootDirectoryProvider,
  }) : _directory = directory,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _externalSaver = externalSaver ?? _saveWithSystemDialog,
       _externalPicker = externalPicker ?? _pickBackupWithSystemDialog,
       _directorySupportChecker =
           directorySupportChecker ?? _isPickDirectorySupported,
       _directoryPicker =
           directoryPicker ?? _pickBackupDirectoryWithSystemDialog,
       _directorySaver = directorySaver ?? _saveToPickedDirectory,
       _rootDirectoryProvider =
           rootDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Directory? _directory;
  final FlutterSecureStorage _secureStorage;
  final ExternalFileSaver _externalSaver;
  final ExternalFilePicker _externalPicker;
  final DirectoryPickerSupportChecker _directorySupportChecker;
  final ExternalDirectoryPicker _directoryPicker;
  final ExternalDirectorySaver _directorySaver;
  final RootDirectoryProvider _rootDirectoryProvider;

  static const _secretKey = 'shift_ledger_webdav_app_password';
  static const _backupDirectoryUriKey = 'shift_ledger_backup_directory_uri';
  static const _dataFileName = 'shift_ledger_data.json';

  Future<LoadedLedgerData?> loadDetailed() async {
    final file = await _dataFile();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final decodeResult = BackupService().decodeWithReport(json);
    final password = await _secureStorage.read(key: _secretKey) ?? '';
    return LoadedLedgerData(
      snapshot: _attachSecret(decodeResult.snapshot, password),
      diagnostics: decodeResult.diagnostics,
    );
  }

  Future<LedgerSnapshot?> load() async => (await loadDetailed())?.snapshot;

  Future<void> save(LedgerSnapshot snapshot) async {
    final file = await _dataFile();
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
      encoder.convert(snapshot.toJson(includeSecrets: false)),
    );
    if (snapshot.webDavConfig.appPassword.isNotEmpty) {
      await _secureStorage.write(
        key: _secretKey,
        value: snapshot.webDavConfig.appPassword,
      );
    } else {
      await _secureStorage.delete(key: _secretKey);
    }
  }

  Future<String?> writeCsv(String csv) async {
    final fileName = 'shift-ledger-${_timestamp()}.csv';
    if (_directory != null) {
      final dir = await _exportsDirectory();
      await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csv, flush: true);
      return file.path;
    }
    return _externalSaver(
      ExternalSaveRequest(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileName: fileName,
        mimeType: 'text/csv',
      ),
    );
  }

  Future<String?> writeBackup(LedgerSnapshot snapshot) async {
    final fileName = 'shift-ledger-backup-${_timestamp()}.json';
    final payload = BackupService().encode(snapshot);
    final bytes = Uint8List.fromList(utf8.encode(payload));
    final dir = await _backupsDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(payload, flush: true);
    if (_directory != null) return file.path;
    final rememberedDirectoryUri = await _readOptionalSecure(
      _backupDirectoryUriKey,
    );
    if (rememberedDirectoryUri != null && rememberedDirectoryUri.isNotEmpty) {
      try {
        final rememberedPath = await _directorySaver(
          DirectorySaveRequest(
            directoryUri: rememberedDirectoryUri,
            bytes: bytes,
            fileName: fileName,
            mimeType: 'application/json',
          ),
        );
        if (rememberedPath != null) return rememberedPath;
      } catch (_) {
        await _deleteOptionalSecure(_backupDirectoryUriKey);
      }
    }
    if (await _directorySupportChecker()) {
      final pickedDirectoryUri = await _directoryPicker();
      if (pickedDirectoryUri != null && pickedDirectoryUri.isNotEmpty) {
        await _writeOptionalSecure(_backupDirectoryUriKey, pickedDirectoryUri);
        final pickedPath = await _directorySaver(
          DirectorySaveRequest(
            directoryUri: pickedDirectoryUri,
            bytes: bytes,
            fileName: fileName,
            mimeType: 'application/json',
          ),
        );
        if (pickedPath != null) return pickedPath;
      }
      return null;
    }
    final externalPath = await _externalSaver(
      ExternalSaveRequest(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'application/json',
      ),
    );
    return externalPath;
  }

  Future<String?> latestBackupPath() async {
    final dir = await _backupsDirectory();
    if (!await dir.exists()) return null;
    final files = await dir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.json'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files.isEmpty ? null : files.first.path;
  }

  Future<LedgerSnapshot> readBackup(String path) async {
    return (await readBackupResult(path)).snapshot;
  }

  Future<String?> pickBackupFilePath() => _externalPicker();

  Future<LoadedLedgerData> readBackupResult(String path) async {
    final map =
        jsonDecode(await File(path).readAsString()) as Map<String, Object?>;
    final decodeResult = BackupService().decodeWithReport(map);
    return LoadedLedgerData(
      snapshot: decodeResult.snapshot,
      diagnostics: decodeResult.diagnostics,
    );
  }

  Future<Directory> _root() async => _directory ?? _rootDirectoryProvider();
  Future<File> _dataFile() async =>
      File('${(await _root()).path}/$_dataFileName');
  Future<Directory> _exportsDirectory() async => _directory == null
      ? Directory('${(await _root()).path}/exports')
      : Directory('${(await _root()).path}/exports');
  Future<Directory> _backupsDirectory() async =>
      Directory('${(await _root()).path}/backups');

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  LedgerSnapshot _attachSecret(LedgerSnapshot snapshot, String password) =>
      LedgerSnapshot(
        entries: snapshot.entries,
        templates: snapshot.templates,
        payRules: snapshot.payRules,
        nightRule: snapshot.nightRule,
        payPeriod: snapshot.payPeriod,
        webDavConfig: snapshot.webDavConfig.copyWith(appPassword: password),
        autoBackupConfig: snapshot.autoBackupConfig,
        recentDeletedDays: snapshot.recentDeletedDays,
      );

  Future<String?> _readOptionalSecure(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeOptionalSecure(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<void> _deleteOptionalSecure(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
  }
}

Future<String?> _saveWithSystemDialog(ExternalSaveRequest request) {
  return FlutterFileDialog.saveFile(
    params: SaveFileDialogParams(
      data: request.bytes,
      fileName: request.fileName,
      mimeTypesFilter: [request.mimeType],
      localOnly: false,
    ),
  );
}

Future<String?> _pickBackupWithSystemDialog() {
  return FlutterFileDialog.pickFile(
    params: const OpenFileDialogParams(
      fileExtensionsFilter: ['json'],
      mimeTypesFilter: ['application/json', 'text/json'],
      localOnly: false,
      copyFileToCacheDir: true,
    ),
  );
}

Future<bool> _isPickDirectorySupported() async {
  try {
    return await FlutterFileDialog.isPickDirectorySupported();
  } catch (_) {
    return false;
  }
}

Future<String?> _pickBackupDirectoryWithSystemDialog() async =>
    (await FlutterFileDialog.pickDirectory())?.toString();

Future<String?> _saveToPickedDirectory(DirectorySaveRequest request) {
  return const MethodChannel(
    'flutter_file_dialog',
  ).invokeMethod<String>('saveFileToDirectory', {
    'directory': request.directoryUri,
    'data': request.bytes,
    'fileName': request.fileName,
    'mimeType': request.mimeType,
    'replace': false,
  });
}
