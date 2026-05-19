import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/auto_backup_service.dart';
import 'package:shift_ledger/src/services/backup_service.dart';

void main() {
  group('AutoBackupService', () {
    test('disabled config stays idle and does not upload', () async {
      final upload = _UploadSpy();
      final state = _configuredState()
        ..updateAutoBackupConfig(const AutoBackupConfig(enabled: false));

      final result = await AutoBackupService(
        uploader: upload.call,
        nowProvider: () => DateTime(2026, 5, 13, 9),
      ).run(state: state);

      expect(upload.calls, isEmpty);
      expect(result.lastStatus, AutoBackupStatus.idle);
    });

    test('missing WebDAV password marks config incomplete', () async {
      final upload = _UploadSpy();
      final now = DateTime(2026, 5, 13, 9);
      final state = LedgerState.empty(now: now)
        ..updateWebDavConfig(
          const WebDavConfig(
            url: 'https://dav.jianguoyun.com/dav/',
            username: 'user@example.com',
            remotePath: 'manual.json',
          ),
        )
        ..updateAutoBackupConfig(const AutoBackupConfig(enabled: true));

      final result = await AutoBackupService(
        uploader: upload.call,
        nowProvider: () => now,
      ).run(state: state);

      expect(upload.calls, isEmpty);
      expect(result.lastStatus, AutoBackupStatus.configIncomplete);
      expect(result.lastAttemptAt, now);
      expect(result.lastError, contains('需重新授权'));
    });

    test('same ledger content hash skips repeat upload', () async {
      final upload = _UploadSpy();
      var now = DateTime(2026, 5, 13, 9);
      final state = _configuredState();
      final service = AutoBackupService(
        uploader: upload.call,
        nowProvider: () => now,
      );

      final first = await service.run(state: state);
      now = now.add(const Duration(hours: 2));
      final second = await service.run(state: state);

      expect(first.lastStatus, AutoBackupStatus.success);
      expect(second.lastStatus, AutoBackupStatus.skipped);
      expect(upload.calls, hasLength(1));
    });

    test('recent success waits until minimum interval passes', () async {
      final upload = _UploadSpy();
      final now = DateTime(2026, 5, 13, 9);
      final state = _configuredState()
        ..updateAutoBackupConfig(
          AutoBackupConfig(
            enabled: true,
            lastSuccessAt: now.subtract(const Duration(minutes: 30)),
            lastContentHash: 'old-content',
            dailyCountDate: DateTime(2026, 5, 13),
            dailySuccessCount: 1,
          ),
        );

      final result = await AutoBackupService(
        uploader: upload.call,
        nowProvider: () => now,
      ).run(state: state);

      expect(upload.calls, isEmpty);
      expect(result.lastStatus, AutoBackupStatus.waiting);
      expect(result.lastAttemptAt, now);
    });

    test('daily cap waits without uploading', () async {
      final upload = _UploadSpy();
      final now = DateTime(2026, 5, 13, 12);
      final state = _configuredState()
        ..updateAutoBackupConfig(
          AutoBackupConfig(
            enabled: true,
            lastSuccessAt: now.subtract(const Duration(hours: 2)),
            lastContentHash: 'old-content',
            dailyCountDate: DateTime(2026, 5, 13),
            dailySuccessCount: 6,
          ),
        );

      final result = await AutoBackupService(
        uploader: upload.call,
        nowProvider: () => now,
      ).run(state: state);

      expect(upload.calls, isEmpty);
      expect(result.lastStatus, AutoBackupStatus.waiting);
    });

    test(
      'eligible config uploads the unified backup file and updates status',
      () async {
        final upload = _UploadSpy();
        final now = DateTime(2026, 5, 13, 9);
        final state = _configuredState();

        final result = await AutoBackupService(
          uploader: upload.call,
          nowProvider: () => now,
        ).run(state: state);

        expect(upload.calls, hasLength(1));
        expect(upload.calls.single.config.remotePath, 'manual-backup.json');
        expect(
          upload.calls.single.payload,
          isNot(contains('secret-app-password')),
        );
        expect(result.lastStatus, AutoBackupStatus.success);
        expect(result.lastSuccessAt, now);
        expect(result.lastAttemptAt, now);
        expect(result.dailyCountDate, DateTime(2026, 5, 13));
        expect(result.dailySuccessCount, 1);
        expect(result.lastContentHash, isNotEmpty);
        expect(state.autoBackupConfig.lastStatus, AutoBackupStatus.success);
        expect(state.autoBackupConfig.remotePath, 'manual-backup.json');
      },
    );

    test('upload failure is captured as status without throwing', () async {
      final now = DateTime(2026, 5, 13, 9);
      final state = _configuredState();

      final result = await AutoBackupService(
        uploader: (_, _) async => throw Exception('network boom'),
        nowProvider: () => now,
      ).run(state: state);

      expect(result.lastStatus, AutoBackupStatus.failed);
      expect(result.lastAttemptAt, now);
      expect(result.lastError, contains('network boom'));
    });

    test('automatic backup preserves recent deleted restore points', () async {
      final upload = _UploadSpy();
      final now = DateTime(2026, 5, 13, 9);
      final state = LedgerState.seeded(now: now)
        ..updateWebDavConfig(
          const WebDavConfig(
            url: 'https://dav.jianguoyun.com/dav/',
            username: 'user@example.com',
            appPassword: 'secret-app-password',
            remotePath: 'manual-backup.json',
          ),
        )
        ..updateAutoBackupConfig(const AutoBackupConfig(enabled: true));
      state.deleteDay(now);

      await AutoBackupService(
        uploader: upload.call,
        nowProvider: () => now,
      ).run(state: state);

      final snapshot = BackupService().decode(
        jsonDecode(upload.calls.single.payload) as Map<String, Object?>,
      );
      expect(snapshot.recentDeletedDays, hasLength(1));
      expect(snapshot.recentDeletedDays.single.segmentCount, 2);
      expect(snapshot.webDavConfig.appPassword, isEmpty);
    });

    test(
      'changing WebDAV destination triggers a fresh upload even within the usual interval',
      () async {
        final upload = _UploadSpy();
        var now = DateTime(2026, 5, 13, 9);
        final state = _configuredState();
        final service = AutoBackupService(
          uploader: upload.call,
          nowProvider: () => now,
        );

        final first = await service.run(state: state);
        expect(first.lastStatus, AutoBackupStatus.success);

        state.updateWebDavConfig(
          state.webDavConfig.copyWith(username: 'other@example.com'),
        );
        now = now.add(const Duration(minutes: 10));
        final second = await service.run(state: state);

        expect(second.lastStatus, AutoBackupStatus.success);
        expect(upload.calls, hasLength(2));
        expect(upload.calls.last.config.username, 'other@example.com');
      },
    );
  });
}

LedgerState _configuredState() => LedgerState.empty(now: DateTime(2026, 5, 13))
  ..updateWebDavConfig(
    const WebDavConfig(
      url: 'https://dav.jianguoyun.com/dav/',
      username: 'user@example.com',
      appPassword: 'secret-app-password',
      remotePath: 'manual-backup.json',
    ),
  )
  ..updateAutoBackupConfig(const AutoBackupConfig(enabled: true));

class _UploadSpy {
  final calls = <({WebDavConfig config, String payload})>[];

  Future<void> call(WebDavConfig config, String payload) async {
    calls.add((config: config, payload: payload));
  }
}
