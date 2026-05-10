# iOS Release Checklist

## Apple Developer

- Apple Developer account is active.
- Bundle ID is registered.
- Push Notifications capability is enabled.
- Associated domains/deep links are reviewed if added later.

## Firebase and Supabase

- iOS app exists in Firebase project.
- `GoogleService-Info.plist` belongs to the production Firebase app.
- Supabase OAuth redirect includes `io.supabase.geomoments://login-callback/`.
- Supabase project secrets do not live in the Flutter repository.

## Xcode

- Open `ios/Runner.xcworkspace`.
- Verify Runner signing team.
- Verify Bundle Identifier.
- Verify Display Name: Geo Moments.
- Verify camera/photo/microphone/location permission descriptions.
- Verify Push Notifications capability.

## Build

```bash
flutter clean
flutter pub get
flutter gen-l10n
dart run build_runner build
flutter analyze
flutter test
flutter build ipa --release
```

Expected output:

```text
build/ios/archive/Runner.xcarchive
build/ios/ipa/*.ipa
```

## Smoke Test

- Install through TestFlight.
- Sign in with OAuth.
- Open map.
- Open details from notification tap.
- Create a moment with media.
- Verify comments/replies push flow.