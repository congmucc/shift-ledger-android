# Android release APK

This project supports two release-signing modes:

1. Local release signing when `android/keystore.properties` exists.
2. Debug-key fallback when the local release keystore is absent, so CI and fresh checkouts can still build an installable APK.

Sensitive files are intentionally ignored by Git:

- `android/shift-ledger-release.jks`
- `android/keystore.properties`

Build command:

```bash
flutter build apk --release
```

Phone install artifact for this handoff is copied to `release/shift-ledger-android-v1.0.0+1-release.apk`.

## Current handoff APK

- Path: 
- SHA-256: 
- Size: about 48 MB
- Signed with local ignored release keystore: .

The APK is committed intentionally for this phone-install handoff. Do not commit  or the keystore file.
