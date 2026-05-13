# Automatic WebDAV Backup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add opt-in, traffic-conscious automatic Nutstore/WebDAV backup for the local-first Shift Ledger app.

**Architecture:** Store automatic backup metadata in the existing ledger snapshot beside `WebDavConfig`, but keep app passwords only in secure storage. Add a small `AutoBackupService` that decides whether to upload based on config completeness, content hash, minimum interval, and daily cap. Wire app lifecycle/data-change scheduling in `ShiftLedgerApp`, and expose controls/status inside the existing WebDAV settings sheet.

**Tech Stack:** Flutter/Dart, existing `ChangeNotifier` state, `BackupService`, `WebDavClient`, `flutter_test` widget/unit tests.

---

## File Structure

- Modify `lib/src/domain/models.dart`: add `AutoBackupStatus`, `AutoBackupConfig`, JSON serialization, and include it in `LedgerSnapshot`.
- Modify `lib/src/app/ledger_state.dart`: store/update auto backup config and keep restore semantics non-secret.
- Create `lib/src/services/auto_backup_service.dart`: hash payloads, evaluate skip/upload decisions, perform automatic WebDAV upload, update status.
- Modify `lib/main.dart`: schedule startup check and debounced data-change checks without background service or notification.
- Modify `lib/src/ui/pages/settings_page.dart`: add WebDAV sheet controls/status for auto backup.
- Modify tests:
  - `test/services/auto_backup_service_test.dart`
  - `test/services/export_backup_test.dart`
  - `test/widget/app_flow_test.dart`

## Task 1: Model and persistence

**Files:**
- Modify: `lib/src/domain/models.dart`
- Modify: `lib/src/app/ledger_state.dart`
- Modify: `test/services/export_backup_test.dart`

- [ ] **Step 1: Write model/persistence tests**

Add assertions to backup tests proving default auto backup is disabled and serializes without secrets:

```dart
final decoded = BackupService().decode(jsonDecode(payload) as Map<String, Object?>);
expect(decoded.autoBackupConfig.enabled, isFalse);
expect(decoded.autoBackupConfig.remotePath, 'shift-ledger-auto-latest.json');
```

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/services/export_backup_test.dart`
Expected: FAIL because `autoBackupConfig` does not exist.

- [ ] **Step 3: Implement model**

Add:

```dart
enum AutoBackupStatus { idle, success, skipped, waiting, configIncomplete, failed }

class AutoBackupConfig {
  const AutoBackupConfig({
    this.enabled = false,
    this.remotePath = 'shift-ledger-auto-latest.json',
    this.lastSuccessAt,
    this.lastAttemptAt,
    this.lastContentHash = '',
    this.dailyCountDate,
    this.dailySuccessCount = 0,
    this.lastStatus = AutoBackupStatus.idle,
    this.lastError = '',
  });
  // fields, copyWith, toJson/fromJson.
}
```

Include `autoBackupConfig` in `LedgerSnapshot` constructor, `toJson`, `fromJson`, and `sanitizedForBackup`.

- [ ] **Step 4: Wire LedgerState**

Add `autoBackupConfig` field, constructor parameter, `updateAutoBackupConfig`, `restore`, and `toSnapshot` support.

- [ ] **Step 5: Verify and commit**

Run:

```bash
flutter test test/services/export_backup_test.dart
flutter analyze
```

Expected: tests pass and analyze has no issues.

Commit:

```bash
git add lib/src/domain/models.dart lib/src/app/ledger_state.dart test/services/export_backup_test.dart
git commit -m "feat: persist automatic backup settings"
```

## Task 2: AutoBackupService decisions and upload

**Files:**
- Create: `lib/src/services/auto_backup_service.dart`
- Create: `test/services/auto_backup_service_test.dart`

- [ ] **Step 1: Write decision tests**

Cover:

- disabled config returns skipped/idle without upload.
- missing WebDAV password returns `configIncomplete`.
- same content hash skips upload.
- last success within 1 hour sets waiting.
- daily success count >= 6 sets waiting.
- eligible config calls uploader with `remotePath = shift-ledger-auto-latest.json`.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/services/auto_backup_service_test.dart`
Expected: FAIL because service does not exist.

- [ ] **Step 3: Implement service**

Create `AutoBackupService` with injectable upload function and clock for tests:

```dart
typedef AutoBackupUploader = Future<void> Function(WebDavConfig config, String payload);
typedef NowProvider = DateTime Function();

class AutoBackupService {
  const AutoBackupService({this.uploader, this.nowProvider});
  final AutoBackupUploader? uploader;
  final NowProvider? nowProvider;

  Future<AutoBackupConfig> run({required LedgerState state}) async { ... }
}
```

Use `sha256.convert(utf8.encode(payload)).toString()` from `dart:convert` + `package:crypto/crypto.dart` if `crypto` is available transitively; otherwise use a stable lightweight hash implemented locally over UTF-8 bytes.

- [ ] **Step 4: Verify and commit**

Run:

```bash
flutter test test/services/auto_backup_service_test.dart
flutter analyze
```

Commit:

```bash
git add lib/src/services/auto_backup_service.dart test/services/auto_backup_service_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: add automatic backup service"
```

## Task 3: App scheduling

**Files:**
- Modify: `lib/main.dart`
- Test: existing widget tests and service tests

- [ ] **Step 1: Implement scheduling**

In `_ShiftLedgerAppState` add timers:

- startup timer: 20 seconds after init.
- change debounce timer: 10 minutes after ledger changes.
- skip auto scheduling when `repository == null` in tests.
- call `AutoBackupService().run(state: widget.state)` and then persist state through existing save listener.

- [ ] **Step 2: Avoid backup loops**

When auto backup updates only `autoBackupConfig`, do not recursively schedule another immediate auto backup. Use a boolean `_runningAutoBackup` guard.

- [ ] **Step 3: Verify and commit**

Run:

```bash
flutter test
flutter analyze
```

Commit:

```bash
git add lib/main.dart
git commit -m "feat: schedule automatic WebDAV backups"
```

## Task 4: WebDAV settings UI

**Files:**
- Modify: `lib/src/ui/pages/settings_page.dart`
- Modify: `test/widget/app_flow_test.dart`

- [ ] **Step 1: Add widget test**

Extend WebDAV widget test to assert:

- `自动云备份` is visible.
- switch defaults off.
- strategy copy includes `最小间隔 1 小时` and `每天最多 6 次`.
- missing password status includes `需重新授权` or `配置不完整`.

- [ ] **Step 2: Run test to verify failure**

Run: `flutter test test/widget/app_flow_test.dart`
Expected: FAIL because UI is missing.

- [ ] **Step 3: Implement UI**

Inside `WebDavSheet`, show a `SwitchListTile` and compact status rows. On switch change, update `state.updateAutoBackupConfig(state.autoBackupConfig.copyWith(enabled: value, lastStatus: AutoBackupStatus.waiting))`.

- [ ] **Step 4: Verify and commit**

Run:

```bash
flutter test test/widget/app_flow_test.dart
flutter analyze
```

Commit:

```bash
git add lib/src/ui/pages/settings_page.dart test/widget/app_flow_test.dart
git commit -m "feat: expose automatic backup settings"
```

## Task 5: Final validation and APK handoff

**Files:**
- Modify: `release/shift-ledger-android-v1.0.0+1-release.apk`
- Modify: `release/shift-ledger-android-v1.0.0+1-release.apk.sha256`
- Modify: `docs/installation/android-release.md`

- [ ] **Step 1: Full verification**

Run:

```bash
flutter analyze
flutter test
flutter build web
flutter build apk --release
git diff --check
```

Expected: analyze/test/build pass. Web build may continue to show non-blocking wasm dry-run warnings from `flutter_secure_storage_web`.

- [ ] **Step 2: Rebuild release artifact**

Run:

```bash
cp build/app/outputs/flutter-apk/app-release.apk release/shift-ledger-android-v1.0.0+1-release.apk
shasum -a 256 release/shift-ledger-android-v1.0.0+1-release.apk > release/shift-ledger-android-v1.0.0+1-release.apk.sha256
/opt/homebrew/bin/apkanalyzer manifest permissions release/shift-ledger-android-v1.0.0+1-release.apk | sort
/opt/homebrew/share/android-commandlinetools/build-tools/35.0.0/apksigner verify --print-certs release/shift-ledger-android-v1.0.0+1-release.apk
```

Expected: permissions include `android.permission.INTERNET`; signature verifies.

- [ ] **Step 3: Update install docs**

Replace APK SHA and size in `docs/installation/android-release.md`.

- [ ] **Step 4: Commit and push**

```bash
git add release/ docs/installation/android-release.md
git commit -m "chore: rebuild APK with automatic backup"
git push origin main
```

## Self-review

- Spec coverage: all design requirements map to tasks 1-5.
- Placeholder scan: no TBD/TODO language remains.
- Type consistency: plan uses `AutoBackupConfig`, `AutoBackupStatus`, and `AutoBackupService.run` consistently.
