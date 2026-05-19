import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/backup_service.dart';
import 'package:shift_ledger/src/services/csv_exporter.dart';
import 'package:shift_ledger/src/services/local_ledger_repository.dart';

void main() {
  test('CSV export contains required audit columns', () {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    final entry = WorkEntry.create(
      workDate: DateTime(2026, 5, 13),
      startDateTime: DateTime(2026, 5, 13, 9),
      endDateTime: DateTime(2026, 5, 13, 18),
      breakMinutes: 60,
      type: EntryType.regular,
      payRule: rule,
      note: '替班',
    );
    final csv = CsvExporter().exportEntries(
      entries: [entry],
      rules: [rule],
      nightRule: NightRule.defaults(),
      range: DateRange.month(2026, 5),
    );

    expect(csv, contains('归属日期,开始日期时间,结束日期时间,跨天标记'));
    expect(csv, contains('计薪规则名称,计薪类型,规则快照摘要'));
    expect(csv, contains('基础收入,加班收入,夜班收入,补贴,扣款,收入合计,备注'));
    expect(csv, contains('替班'));
  });

  test('CSV export uses range-prorated hours for cross-boundary shifts', () {
    final rule = PayRule.defaultHourly(hourlyRate: 10);
    final entry = WorkEntry.create(
      workDate: DateTime(2026, 5, 31),
      startDateTime: DateTime(2026, 5, 31, 22),
      endDateTime: DateTime(2026, 6, 1, 6),
      breakMinutes: 60,
      type: EntryType.regular,
      payRule: rule,
    );

    final csv = CsvExporter().exportEntries(
      entries: [entry],
      rules: [rule],
      nightRule: NightRule.defaults(),
      range: DateRange.month(2026, 6),
    );

    expect(
      csv,
      contains('2026-05-31,2026-05-31 22:00,2026-06-01 06:00,是,45,5.25,5.25'),
    );
    expect(csv, contains('总工时,5.25'));
  });

  test('backup excludes WebDAV app password but restores ledger data', () {
    final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
    state.updateWebDavConfig(
        const WebDavConfig(
          url: 'https://dav.jianguoyun.com/dav/shift-ledger',
          username: 'user@example.com',
          appPassword: 'secret-app-password',
          remotePath: _legacyRootRemotePath,
        ),
      );

    final payload = BackupService().encode(state.toSnapshot());
    expect(payload, isNot(contains('secret-app-password')));
    expect(payload, contains('user@example.com'));

    final decoded = BackupService().decode(
      jsonDecode(payload) as Map<String, Object?>,
    );
    expect(decoded.entries, isNotEmpty);
    expect(decoded.webDavConfig.appPassword, isEmpty);
    expect(decoded.autoBackupConfig.enabled, isFalse);
    expect(decoded.autoBackupConfig.remotePath, defaultWebDavRemotePath);

    state.restore(decoded);
    expect(state.webDavConfig.username, 'user@example.com');
    expect(state.webDavConfig.appPassword, isEmpty);
    expect(state.webDavConfig.isConfigured, isFalse);
    expect(state.webDavConfig.remotePath, defaultWebDavRemotePath);
  });

  test(
    'backup decode skips malformed entries instead of failing all restore',
    () {
      final rule = PayRule.defaultHourly(hourlyRate: 35);
      final validEntry = WorkEntry.create(
        workDate: DateTime(2026, 5, 13),
        startDateTime: DateTime(2026, 5, 13, 9),
        endDateTime: DateTime(2026, 5, 13, 18),
        breakMinutes: 60,
        type: EntryType.regular,
        payRule: rule,
      );

      final snapshot = BackupService().decode({
        'entries': [
          validEntry.toJson(),
          {
            'id': 'bad_entry',
            'workDate': '2026-05-14',
            'startDateTime': 'not-a-date',
            'endDateTime': '2026-05-14T18:00:00',
            'payRuleSnapshot': rule.toJson(),
          },
        ],
        'payRules': [rule.toJson()],
        'templates': const [],
        'nightRule': NightRule.defaults().toJson(),
        'payPeriod': const PayPeriod().toJson(),
        'webDavConfig': const WebDavConfig().toJson(),
      });

      expect(snapshot.entries, hasLength(1));
      expect(snapshot.entries.single.id, validEntry.id);
    },
  );

  test('backup decode reports skipped malformed top-level records', () {
    final rule = PayRule.defaultHourly(hourlyRate: 35);
    final result = BackupService().decodeWithReport({
      'entries': [
        {
          'id': 'bad_entry',
          'workDate': '2026-05-14',
          'startDateTime': 'not-a-date',
          'endDateTime': '2026-05-14T18:00:00',
          'payRuleSnapshot': rule.toJson(),
        },
      ],
      'payRules': [
        rule.toJson(),
        {'id': 'bad_rule', 'name': '坏规则', 'effectiveFrom': 'not-a-date'},
      ],
      'templates': const [],
      'nightRule': NightRule.defaults().toJson(),
      'payPeriod': const PayPeriod().toJson(),
      'webDavConfig': const WebDavConfig().toJson(),
      'recentDeletedDays': const [
        {'id': 'bad_deleted', 'day': 'not-a-day'},
      ],
    });

    expect(result.snapshot.entries, isEmpty);
    expect(result.diagnostics.hasWarnings, isTrue);
    expect(result.diagnostics.malformedEntries, 1);
    expect(result.diagnostics.malformedPayRules, 1);
    expect(result.diagnostics.malformedDeletedDays, 1);
    expect(result.diagnostics.summary, contains('1条工时记录'));
  });

  test('backup decode treats malformed entry containers as empty lists', () {
    final snapshot = BackupService().decode({
      'entries': 'not-a-list',
      'payRules': 'not-a-list',
      'templates': 'not-a-list',
      'nightRule': NightRule.defaults().toJson(),
      'payPeriod': const PayPeriod().toJson(),
      'webDavConfig': const WebDavConfig().toJson(),
    });

    expect(snapshot.entries, isEmpty);
    expect(snapshot.payRules, isEmpty);
    expect(snapshot.templates, isEmpty);
  });

  test('Android release manifest includes Internet permission for WebDAV', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:label="工时账本"'));
  });

  test(
    'repository uses injected external saver for production exports',
    () async {
      final calls = <ExternalSaveRequest>[];
      final repository = LocalLedgerRepository(
        externalSaver: (request) async {
          calls.add(request);
          return '/picked/${request.fileName}';
        },
      );

      final path = await repository.writeCsv('a,b\n1,2');

      expect(path, startsWith('/picked/shift-ledger-'));
      expect(calls.single.mimeType, 'text/csv');
      expect(calls.single.fileName, endsWith('.csv'));
      expect(utf8.decode(calls.single.bytes), 'a,b\n1,2');
    },
  );

  test(
    'production backup keeps a private restore copy separate from external save',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'shift-ledger-backup-test',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final calls = <ExternalSaveRequest>[];
      final repository = LocalLedgerRepository(
        rootDirectoryProvider: () async => tempDir,
        externalSaver: (request) async {
          calls.add(request);
          return '/picked/${request.fileName}';
        },
      );

      final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
      final externalPath = await repository.writeBackup(state.toSnapshot());
      final internalPath = await repository.latestBackupPath();

      expect(externalPath, startsWith('/picked/shift-ledger-backup-'));
      expect(internalPath, isNotNull);
      expect(internalPath, startsWith('${tempDir.path}/backups/'));
      expect(calls.single.mimeType, 'application/json');
      expect(utf8.decode(calls.single.bytes), contains('"entries"'));
    },
  );

  test(
    'production backup reports external save cancellation while keeping private copy',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'shift-ledger-backup-cancel-test',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final repository = LocalLedgerRepository(
        rootDirectoryProvider: () async => tempDir,
        externalSaver: (_) async => null,
      );

      final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
      final externalPath = await repository.writeBackup(state.toSnapshot());
      final internalPath = await repository.latestBackupPath();

      expect(externalPath, isNull);
      expect(internalPath, isNotNull);
      expect(internalPath, startsWith('${tempDir.path}/backups/'));
    },
  );

  test(
    'production backup remembers the first picked directory and auto-saves later backups there',
    () async {
      final originalPlatform = FlutterSecureStoragePlatform.instance;
      FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
        <String, String>{},
      );
      addTearDown(
        () => FlutterSecureStoragePlatform.instance = originalPlatform,
      );

      final tempDir = await Directory.systemTemp.createTemp(
        'shift-ledger-backup-remember-dir-test',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final pickedDirectories = <String>[];
      final savedRequests = <DirectorySaveRequest>[];
      final repository = LocalLedgerRepository(
        rootDirectoryProvider: () async => tempDir,
        directorySupportChecker: () async => true,
        directoryPicker: () async {
          pickedDirectories.add('content://picked/ledger-backups');
          return 'content://picked/ledger-backups';
        },
        directorySaver: (request) async {
          savedRequests.add(request);
          return '/picked/${request.fileName}';
        },
        externalSaver: (_) async =>
            throw StateError('should not open the one-off save dialog'),
      );

      final state = LedgerState.seeded(now: DateTime(2026, 5, 13));
      final firstPath = await repository.writeBackup(state.toSnapshot());
      final secondPath = await repository.writeBackup(state.toSnapshot());

      expect(firstPath, startsWith('/picked/shift-ledger-backup-'));
      expect(secondPath, startsWith('/picked/shift-ledger-backup-'));
      expect(pickedDirectories, hasLength(1));
      expect(savedRequests, hasLength(2));
      expect(
        savedRequests.every(
          (request) =>
              request.directoryUri == 'content://picked/ledger-backups',
        ),
        isTrue,
      );
    },
  );

  test(
    'repository uses injected external picker for cross-device restore',
    () async {
      final repository = LocalLedgerRepository(
        externalPicker: () async => '/picked/shift-ledger-backup.json',
      );

      final path = await repository.pickBackupFilePath();

      expect(path, '/picked/shift-ledger-backup.json');
    },
  );
}

const _legacyRootRemotePath = 'shift-ledger-backup.json';
