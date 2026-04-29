# Target Architecture

## Product shape

Geo Moments состоит из нескольких простых пользовательских сценариев:

1. Пользователь входит через Google или Apple.
2. Видит карту с ближайшими моментами.
3. Открывает маркер и смотрит карточку момента.
4. Создает момент: фото/видео, короткий текст, эмоция/категория, координаты.
5. Лайкает момент.
6. Оставляет комментарий или ответ.
7. Получает push при новом ответе или комментарии к своему моменту.
8. Меняет язык и тему.
9. Редактирует базовый профиль.

## Layers

```text
UI widgets/screens
  -> controllers/providers
  -> use cases
  -> repositories abstractions
  -> repositories implementations
  -> remote/local data sources
  -> Supabase/Firebase/platform plugins
```

## Planned package layout

```text
lib/
  main.dart
  src/
    app/
      app.dart
      router/
      theme/
      localization/
      bootstrap/
    core/
      config/
      errors/
      result/
      logging/
      platform/
      widgets/
    features/
      auth/
      profile/
      map/
      moments/
      media/
      comments/
      notifications/
      settings/
```

## Dependency direction

- `core` не зависит от feature.
- `app` собирает зависимости и маршруты.
- `features/*/domain` не зависит от Flutter SDK, Supabase или Firebase.
- `features/*/data` знает про Supabase/Firebase/plugin API.
- `features/*/presentation` знает про Flutter и Riverpod.

## Main domain entities

```text
UserProfile
  id
  displayName
  avatarUrl
  preferredLocale
  themeMode
  createdAt

Moment
  id
  authorId
  lat
  lng
  mediaType
  mediaUrl
  thumbnailUrl
  text
  emotion
  likeCount
  commentCount
  createdAt

Comment
  id
  momentId
  authorId
  parentCommentId
  text
  createdAt

MomentLike
  momentId
  userId
  createdAt

PushToken
  userId
  token
  platform
  updatedAt
```

## Supabase database draft

MVP tables:

- `profiles`
- `moments`
- `moment_likes`
- `comments`
- `push_tokens`

Storage buckets:

- `moment-media`
- `avatars`

Security:

- RLS enabled on all user-facing tables.
- Public read for published moments.
- Insert/update/delete only by owner where appropriate.
- Comments insert only for authenticated users.
- Push tokens visible only to owner and server role.

## Navigation draft

```text
/splash
/auth
/map
/moments/new
/moments/:id
/moments/:id/comments
/profile/:id
/settings
```

## Testing strategy

Every chapter must leave the app buildable.

Minimum checks:

- `flutter analyze`
- `flutter test`

Focused tests:

- pure Dart tests for use cases and mappers;
- widget tests for screens with fake providers;
- integration/manual checks for camera, map, auth, push, release build.

