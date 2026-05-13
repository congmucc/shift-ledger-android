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

- Recommended modern Android phone APK: `release/shift-ledger-android-v1.0.2-arm64-v8a-release.apk`
- Recommended APK SHA-256: `9a7d810d74be570a5ea7eb711b0da46c49d4edb949458b3b1cc82186d98f7ac8`
- Recommended APK size: about 18.0 MB
- Universal fallback APK: `release/shift-ledger-android-v1.0.2-release.apk`
- Universal APK SHA-256: `8f1ce12ad27d1968f4693068de67dc6c2b34624919c0e40932e8ea36c70d44aa`
- Universal APK size: about 51.8 MB
- Signing certificate SHA-256: `cc689600d205573a0fe81b9af7a9c5ee72faac1e02d2e9b7051ae14d84b467e9`

The APK artifacts are committed intentionally for this phone-install handoff. Use the arm64 APK for most modern Android phones; use the universal APK only if the arm64 APK is incompatible. Do not commit `android/keystore.properties` or the keystore file.
