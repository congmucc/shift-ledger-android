import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/models.dart';
import 'backup_service.dart';

class LocalLedgerRepository {
  LocalLedgerRepository({
    Directory? directory,
    FlutterSecureStorage? secureStorage,
  }) : _directory = directory,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final Directory? _directory;
  final FlutterSecureStorage _secureStorage;

  static const _secretKey = 'shift_ledger_webdav_app_password';
  static const _dataFileName = 'shift_ledger_data.json';

  Future<LedgerSnapshot?> load() async {
    final file = await _dataFile();
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final snapshot = LedgerSnapshot.fromJson(json);
    final password = await _secureStorage.read(key: _secretKey) ?? '';
    return LedgerSnapshot(
      entries: snapshot.entries,
      templates: snapshot.templates,
      payRules: snapshot.payRules,
      nightRule: snapshot.nightRule,
      payPeriod: snapshot.payPeriod,
      webDavConfig: snapshot.webDavConfig.copyWith(appPassword: password),
      autoBackupConfig: snapshot.autoBackupConfig,
    );
  }

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

  Future<String> writeCsv(String csv) async {
    final dir = await _exportsDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/shift-ledger-${_timestamp()}.csv');
    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  Future<String> writeBackup(LedgerSnapshot snapshot) async {
    final dir = await _backupsDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/shift-ledger-backup-${_timestamp()}.json');
    await file.writeAsString(BackupService().encode(snapshot), flush: true);
    return file.path;
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
    final map =
        jsonDecode(await File(path).readAsString()) as Map<String, Object?>;
    return BackupService().decode(map);
  }

  Future<Directory> _root() async =>
      _directory ?? getApplicationDocumentsDirectory();
  Future<File> _dataFile() async =>
      File('${(await _root()).path}/$_dataFileName');
  Future<Directory> _exportsDirectory() async => _directory == null
      ? _downloadsAppDirectory()
      : Directory('${(await _root()).path}/exports');
  Future<Directory> _backupsDirectory() async => _directory == null
      ? _downloadsAppDirectory()
      : Directory('${(await _root()).path}/backups');

  Future<Directory> _downloadsAppDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return Directory('${downloads.path}/Shift Ledger');
    }
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download/Shift Ledger');
    }
    return Directory('${(await _root()).path}/Shift Ledger');
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
