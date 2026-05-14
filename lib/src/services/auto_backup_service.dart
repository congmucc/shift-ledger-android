import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../app/ledger_state.dart';
import '../domain/models.dart';
import 'backup_service.dart';
import 'webdav_client.dart';

typedef AutoBackupUploader =
    Future<void> Function(WebDavConfig config, String payload);
typedef NowProvider = DateTime Function();

class AutoBackupService {
  const AutoBackupService({this.uploader, this.nowProvider});

  static const minInterval = Duration(hours: 1);
  static const maxDailySuccessCount = 6;

  final AutoBackupUploader? uploader;
  final NowProvider? nowProvider;

  Future<AutoBackupConfig> run({required LedgerState state}) async {
    final now = nowProvider?.call() ?? DateTime.now();
    final config = state.autoBackupConfig;

    if (!config.enabled) {
      return _apply(state, config.copyWith(lastStatus: AutoBackupStatus.idle));
    }

    if (!state.webDavConfig.isConfigured) {
      return _apply(
        state,
        config.copyWith(
          lastAttemptAt: now,
          lastStatus: AutoBackupStatus.configIncomplete,
          lastError: '需重新授权或配置不完整',
        ),
      );
    }

    final contentHash = _contentHash(state);
    if (config.lastContentHash == contentHash) {
      return _apply(
        state,
        config.copyWith(
          lastAttemptAt: now,
          lastStatus: AutoBackupStatus.skipped,
          lastError: '',
        ),
      );
    }

    final lastSuccessAt = config.lastSuccessAt;
    if (lastSuccessAt != null && now.difference(lastSuccessAt) < minInterval) {
      return _apply(
        state,
        config.copyWith(
          lastAttemptAt: now,
          lastStatus: AutoBackupStatus.waiting,
          lastError: '',
        ),
      );
    }

    final today = dateOnly(now);
    final successCount = _successCountFor(config, today);
    if (successCount >= maxDailySuccessCount) {
      return _apply(
        state,
        config.copyWith(
          lastAttemptAt: now,
          lastStatus: AutoBackupStatus.waiting,
          lastError: '',
        ),
      );
    }

    final next = config.copyWith(
      lastSuccessAt: now,
      lastAttemptAt: now,
      lastContentHash: contentHash,
      dailyCountDate: today,
      dailySuccessCount: successCount + 1,
      lastStatus: AutoBackupStatus.success,
      lastError: '',
    );

    try {
      final uploadConfig = state.webDavConfig.copyWith(
        remotePath: config.remotePath,
      );
      await (uploader ?? WebDavClient().uploadBackup)(
        uploadConfig,
        _payloadWithAutoConfig(state, next),
      );
      return _apply(state, next);
    } catch (error) {
      return _apply(
        state,
        config.copyWith(
          lastAttemptAt: now,
          lastStatus: AutoBackupStatus.failed,
          lastError: _shortError(error),
        ),
      );
    }
  }

  AutoBackupConfig _apply(LedgerState state, AutoBackupConfig config) {
    if (!identical(state.autoBackupConfig, config)) {
      state.updateAutoBackupConfig(config);
    }
    return config;
  }

  int _successCountFor(AutoBackupConfig config, DateTime today) {
    if (config.dailyCountDate == null ||
        ymd(config.dailyCountDate!) != ymd(today)) {
      return 0;
    }
    return config.dailySuccessCount;
  }

  String _contentHash(LedgerState state) {
    final stableConfig = AutoBackupConfig(
      enabled: state.autoBackupConfig.enabled,
      remotePath: state.autoBackupConfig.remotePath,
    );
    final payload = _payloadWithAutoConfig(state, stableConfig);
    return sha256.convert(utf8.encode(payload)).toString();
  }

  String _payloadWithAutoConfig(LedgerState state, AutoBackupConfig config) {
    final snapshot = state.toSnapshot();
    return BackupService().encode(
      LedgerSnapshot(
        entries: snapshot.entries,
        templates: snapshot.templates,
        payRules: snapshot.payRules,
        nightRule: snapshot.nightRule,
        payPeriod: snapshot.payPeriod,
        webDavConfig: snapshot.webDavConfig,
        autoBackupConfig: config,
        recentDeletedDays: snapshot.recentDeletedDays,
      ),
    );
  }

  String _shortError(Object error) {
    final text = '$error'.replaceAll('\n', ' ').trim();
    if (text.length <= 160) return text;
    return '${text.substring(0, 160)}…';
  }
}
