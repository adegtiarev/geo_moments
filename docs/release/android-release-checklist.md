# Android Release Checklist

## Secrets

- `.env` exists locally and is not committed.
- `android/key.properties` exists locally and is not committed.
- Upload keystore exists outside the repository.
- Firebase service account JSON is not committed.
- Supabase service role secrets are not committed.

## Identity

- `applicationId` is final: `arg.adegtiarev.geo_moments`.
- Android app in Firebase uses the same package name.
- Google OAuth Android client uses the correct package/signing fingerprint.
- Supabase OAuth redirect is still `io.supabase.geomoments://login-callback/`.

## Quality Gate

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test docs/course
flutter analyze
flutter test
```

## Build

```bash
flutter build appbundle --release
flutter build apk --release --split-per-abi
```

Do not upload artifacts signed with the debug fallback. For store release,
`android/key.properties` must exist locally and point to the upload keystore.

## Artifacts

- `build/app/outputs/bundle/release/app-release.aab`
- `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`
- `build/app/outputs/flutter-apk/app-x86_64-release.apk`

## Smoke Test

- Install release APK on a physical Android device.
- Sign in/out.
- Open map and details.
- Check compact preview and tablet side panel if available.
- Create a moment with media.
- Like/unlike.
- Comment/reply.
- Verify push notification tap.
- Restart offline and verify cached moments/details.
