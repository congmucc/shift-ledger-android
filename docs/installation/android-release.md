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

Phone install artifacts for this handoff are committed at:

- Recommended modern Android phone APK: `release/shift-ledger-android-v1.0.0+1-arm64-v8a-release.apk`
- Recommended APK SHA-256: `a26c049133cff58191b1e3c9dd1c4b9eddb6cf17e8023f9608aa1ba3d1e44864`
- Recommended APK size: about 17.6 MB
- Universal fallback APK: `release/shift-ledger-android-v1.0.0+1-release.apk`
- Universal APK SHA-256: `a84fa85b1f54b0116441c28d511599c906048418f0387bccb7b0971d41b5dba0`
- Universal APK size: about 50.5 MB
- Signing certificate SHA-256: `cc689600d205573a0fe81b9af7a9c5ee72faac1e02d2e9b7051ae14d84b467e9`

The APK artifacts are committed intentionally for this phone-install handoff. Use the arm64 APK for most modern Android phones; use the universal APK only if the arm64 APK is incompatible. Do not commit `android/keystore.properties` or the keystore file.
