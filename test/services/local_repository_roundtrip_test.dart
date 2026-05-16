import 'dart:io';

import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ledger/src/app/ledger_state.dart';
import 'package:shift_ledger/src/domain/models.dart';
import 'package:shift_ledger/src/services/local_ledger_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('repository save and load roundtrip preserves snapshot and restores secret from secure storage', () async {
    final oldPlatform = FlutterSecureStoragePlatform.instance;
    final secureData = <String, String>{};
    FlutterSecureStoragePlatform.instance = _MemorySecureStoragePlatform(
      secureData,
    );
    addTearDown(() {
      FlutterSecureStoragePlatform.instance = oldPlatform;
    });

    final tempDir = await Directory.systemTemp.createTemp(
      'shift-ledger-repository-roundtrip',
    );
    addTearDown(() => tempDir.delete(recursive: true));

    final state = LedgerState.seeded(now: DateTime(2026, 5, 13))
      ..updateWebDavConfig(
        const WebDavConfig(
          url: 'https://dav.jianguoyun.com/dav/',
          username: 'user@example.com',
          appPassword: 'secret-app-password',
          remotePath: 'manual-backup.json',
        ),
      )
      ..updateAutoBackupConfig(
        const AutoBackupConfig(
          enabled: true,
          remotePath: 'shift-ledger-auto-latest.json',
        ),
      );

    final repository = LocalLedgerRepository(
      rootDirectoryProvider: () async => tempDir,
    );

    await repository.save(state.toSnapshot());
    final loaded = await repository.load();

    expect(loaded, isNotNull);
    expect(loaded!.entries.length, state.entries.length);
    expect(loaded.templates.length, state.templates.length);
    expect(loaded.payRules.length, state.payRules.length);
    expect(loaded.webDavConfig.username, 'user@example.com');
    expect(loaded.webDavConfig.appPassword, 'secret-app-password');
    expect(loaded.autoBackupConfig.enabled, isTrue);
    expect(
      await File('${tempDir.path}/shift_ledger_data.json').readAsString(),
      isNot(contains('secret-app-password')),
    );
    expect(
      secureData['shift_ledger_webdav_app_password'],
      'secret-app-password',
    );
  });
}

class _MemorySecureStoragePlatform extends FlutterSecureStoragePlatform {
  _MemorySecureStoragePlatform(this.data);

  final Map<String, String> data;

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => data.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    data.remove(key);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    data.clear();
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => data[key];

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => data;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    data[key] = value;
  }
}
