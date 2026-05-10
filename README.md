# Geo Moments

Geo Moments - emotions in points

## Course

This repository is used as a practical Flutter course project. The goal is to build a cross-platform Android/iOS app from scratch to a release-ready portfolio MVP.

Course documentation starts here:

- [Course README](docs/course/README.md)
- [Current state](docs/course/STATE.md)
- [Roadmap](docs/course/ROADMAP.md)
- [Target architecture](docs/course/ARCHITECTURE.md)

## App idea

Geo Moments lets users leave a photo/video moment on a map with a short emotional description, likes, comments, and replies.

Planned stack:

- Flutter + Riverpod
- Supabase Auth/Postgres/Storage/Realtime
- Firebase Cloud Messaging
- Camera photo/video
- Mapbox
- Drift/SQLite local read cache
- English/Russian/Spanish localization
- Light/dark theme
- Phone/tablet and portrait/landscape support

## Development checks

Run these before considering a course chapter complete:

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test docs/course
flutter analyze
flutter test
```

Use `flutter run` for manual checks involving Mapbox, camera/media capture, OAuth, push notifications, and platform permissions.

## Required environment

Copy `.env.example` to `.env` and fill in the local Supabase and Mapbox values. Do not commit `.env`, Firebase service account JSON files, or Supabase service role secrets.
