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

Phone install artifact for this handoff is committed at:

- Path: `release/shift-ledger-android-v1.0.0+1-release.apk`
- SHA-256: `5b45b22162b20845e7ee31f55d5fabde7b5cb80dd555ee8f9d587b0311f86762`
- Size: about 50 MB
- Signing certificate SHA-256: `cc689600d205573a0fe81b9af7a9c5ee72faac1e02d2e9b7051ae14d84b467e9`

The APK is committed intentionally for this phone-install handoff. Do not commit `android/keystore.properties` or the keystore file.
