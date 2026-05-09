# Course State

Последнее обновление: 2026-05-09

## Статус

Текущая стадия: `11-likes`

Глава 10 завершена пользователем и проверена. Проект имеет базовый Flutter-каркас с Riverpod, `MaterialApp.router`, `go_router`, light/dark theme, ручным переключателем темы, design tokens, локализацию EN/RU/ES, Supabase bootstrap/config foundation, auth flow через Supabase OAuth, SQL migrations для `profiles`/`moments`, RLS policies, `moment-media` bucket и storage policies, seed data, Flutter domain/data/presentation layer для чтения moments из Supabase, настоящий Mapbox map screen с markers, responsive layout, location permission, marker/list preview bottom sheet, details route `/moments/:momentId` и create route `/moments/new` с настоящим upload/save flow.

## Уже сделано

- Создан Flutter-проект `geo_moments`.
- Зафиксирована идея приложения: Geo Moments - "эмоции в точках".
- Создана документационная структура курса.
- Сформирован roadmap разработки и обучения.
- Выбраны базовые архитектурные решения.
- Переработан стандарт уроков: теперь главы должны объяснять понятия подробно, с примерами кода и частыми ошибками.
- Глава 1 переписана в подробный учебный формат.
- Реализована глава 1: counter-template удален, app root вынесен в `lib/src/app/app.dart`, router вынесен в `app_router.dart`, тема вынесена в `app_theme.dart`.
- Исправлен переход в настройки: используется `context.push(...)`, чтобы системная Back-кнопка возвращала на карту.
- Проверки главы 1 проходили: `flutter analyze`, `flutter test`.
- Реализована глава 2: добавлен `ThemeModeController`, selector темы в настройках, `AppSpacing`, `AppRadius`, `AppBreakpoints`, responsive `MapScreen`.
- Добавлены widget previews для map feature components.
- Проверки главы 2 проходили: `flutter analyze`, `flutter test`; ручная проверка переключения темы выполнена.
- Реализована глава 3: добавлены `flutter_localizations`, `intl`, `l10n.yaml`, ARB-файлы EN/RU/ES, generated localizations, `LocaleController`, `LocaleSelector`.
- Hardcoded UI strings текущих экранов заменены на `context.l10n`.
- Проверки главы 3 проходили: `flutter gen-l10n`, `flutter analyze`, `flutter test`; ручная проверка переключения языка выполнена.
- Реализована глава 4: добавлены `supabase_flutter`, `flutter_dotenv`, `.env.example`, `AppConfig`, `bootstrap`, `supabaseClientProvider`, backend status в Settings.
- `.env` игнорируется Git, реальные Supabase ключи не должны попадать в репозиторий.
- Проверки главы 4 проходили: `flutter gen-l10n`, `flutter analyze`, `flutter test`; ручная проверка backend status выполнена.
- Реализована глава 5: добавлены Google OAuth setup, deep links Android/iOS, auth state stream, `AuthScreen`, auth gate в router, `AppUser`, `AuthRepository`, `SupabaseAuthRepository`, sign out и current user в Settings.
- Проверки главы 5 проходили: `flutter gen-l10n`, `flutter analyze`, `flutter test`; ручная проверка sign in/out выполнена или готова к проверке после OAuth credentials.
- Реализована глава 6: добавлены migration files `202605050001_create_profiles_and_moments.sql` и `202605050002_seed_dev_moments.sql`, таблицы `profiles`/`moments`, triggers, RLS policies, RPC `nearby_moments`, storage bucket `moment-media`.
- Добавлены `Moment`, `MomentDto`, `MomentsRepository`, `SupabaseMomentsRepository`, `momentsRepositoryProvider`, `nearbyMomentsProvider`.
- `MapScreen` показывает список seed moments через `NearbyMomentsList`; widget tests подменяют auth и moments providers fake data.
- Фактический код на 2026-05-06 соответствует завершенной главе 6; пользователь сообщил, что приложение показывает seed moments из Supabase.
- Реализована глава 7: добавлены `mapbox_maps_flutter`, `permission_handler`, `MAPBOX_ACCESS_TOKEN`, Mapbox bootstrap, Android/iOS location permission config.
- Добавлены `MapCameraCenter`, `LocationPermissionController`, `MapboxMapPanel`, `mapSurfaceBuilderProvider`, `MomentPreviewSheet`.
- `MapScreen` стал `ConsumerStatefulWidget`: хранит текущий center, не уничтожает native map при refresh moments, сохраняет последние visible moments, использует responsive phone/tablet layout.
- Seed moments отображаются на карте как circle annotations; tap по marker открывает bottom sheet preview.
- Исправлены ошибки главы 7: bottom sheet больше не узкий, карта не возвращается к стартовой позиции при drag.
- Проверки главы 7 проходили: `flutter gen-l10n`, `flutter analyze`, `flutter test`; ручная Android-проверка карты выполнена пользователем.
- Реализована глава 8: добавлены route `/moments/:momentId`, `AppRoutePaths.momentDetails(id)`, `MomentsRepository.fetchMomentById`, `SupabaseMomentsRepository.fetchMomentById`, `momentDetailsProvider`.
- Добавлены `MomentPreviewCard`, `MomentDetailsScreen`, `MomentDetailsContent`, `MomentDetailsSkeleton`, `MomentErrorView`, `MomentMediaView`.
- `MomentPreviewSheet` теперь показывает reusable preview card и кнопку `View details`.
- `NearbyMomentsList` умеет принимать `onMomentTap`; marker tap и list tap открывают один preview flow.
- `Moment` и DTO подготовлены к `likeCount`, `commentCount`, `mediaUrl`, `mediaType`, `authorAvatarUrl`.
- Исправлен новый widget test главы 8: details content проверяется после scroll внутри `ListView`, потому что media placeholder занимает первый viewport.
- Проверки после главы 8 проходили: `flutter analyze`, `flutter test`.
- Реализована глава 9: добавлен `image_picker`, Android/iOS permission metadata для camera/photo/video, route `/moments/new`, create button на `MapScreen`.
- Добавлены `PickedMomentMedia`, `CreateMomentDraft`, `MomentMediaPicker`, `ImagePickerMomentMediaPicker`, `CreateMomentDraftController`, `CreateMomentScreen`, `CreateMomentMediaPreview`.
- Media picker спрятан за interface, UI не вызывает `ImagePicker` напрямую.
- `CreateMomentScreen` поддерживает photo/video actions, preview, text/emotion inputs, validation и Android lost-data restore через `retrieveLostData()`.
- Исправлен routing conflict главы 9: `/moments/new` стоит перед `/moments/:momentId`.
- Ограничена высота create media preview, чтобы form fields были доступны в widget tests и на широких viewport.
- Перед главой 10 исправлен UX location button: кнопка теперь не только запрашивает permission, но и отправляет карте одноразовую команду focus на текущий location puck через `FollowPuckViewportState`; tooltip обновлен на "Show my location".
- Проверки после главы 9 проходили: `flutter analyze`, `flutter test`.
- Реализована глава 10: добавлена migration `202605070001_moment_media_storage_policies.sql` для `moment-media` upload/select/delete policies.
- Create route `/moments/new` получает `lat/lng` query parameters; create button на карте передает текущий `_center`, а router fallback-ит к Buenos Aires при отсутствующих координатах.
- `CreateMomentDraft` хранит `latitude`/`longitude` и использует `canSubmit`; `CreateMomentScreen` принимает coordinates, выставляет их в draft controller и публикует через `Publish`.
- Добавлены `UploadedMomentMedia`, `CreateMomentCommand`, `MomentMediaStorage`, `SupabaseMomentMediaStorage`, `createMomentSaveControllerProvider`.
- `SupabaseMomentMediaStorage` загружает local file в Supabase Storage через `upload(..., FileOptions(cacheControl, upsert: false, contentType))`, получает public URL через `getPublicUrl` и умеет `remove` для rollback.
- `MomentsRepository.createMoment` и `SupabaseMomentsRepository.createMoment` делают insert row в `moments` через `.insert(...).select(...).single()`.
- Save controller показывает stages `uploadingMedia`/`savingMoment`, сбрасывает draft и invalidates nearby moments после успеха.
- Если insert row падает после upload, controller удаляет загруженный object через `MomentMediaStorage.remove`.
- Добавлен `test/create_moment_save_controller_test.dart`: fake storage и fake repository реально используются через provider overrides; rollback удаления проверяется.
- Widget tests обновлены под `Publish`, scrollable details и location focus command.
- Проверки после главы 10 проходили 2026-05-09: `flutter gen-l10n`, `flutter analyze`, `flutter test`.

## Следующая глава

Текущая глава: [11 Likes](lessons/11-likes.md)

Цель главы: добавить idempotent like/unlike flow:

- добавить таблицу `moment_likes` с primary key `(moment_id, user_id)`;
- добавить RLS policies для select authenticated и insert/delete own likes;
- добавить RPC `moment_like_summary`, `like_moment`, `unlike_moment`;
- обновить `nearby_moments`, чтобы он возвращал `like_count`;
- добавить `MomentLikeSummary`, DTO и `MomentLikesRepository`;
- реализовать Supabase repository через актуальный `rpc(...)` API;
- добавить `MomentLikeController` с optimistic update, disabled button while busy и rollback при ошибке;
- добавить `MomentLikeButton` в details;
- сохранить tests через fake repository, который реально override-ит provider;
- проверить `supabase db push`, `flutter gen-l10n`, `flutter analyze`, `flutter test`, ручной Android сценарий like/unlike.

## Правило продолжения в новом чате

Если пользователь пишет "продолжаем":

1. Прочитать этот файл.
2. Проверить фактическое состояние кода.
3. Открыть файл текущей главы из `docs/course/lessons`.
4. Кратко напомнить, где остановились.
5. Проверить незакоммиченный код пользователя перед продолжением практики.
6. Не переходить к следующей главе без явного подтверждения пользователя.

## Последняя известная структура проекта

```text
lib/main.dart              entrypoint с ProviderScope
lib/src/app/app.dart       GeoMomentsApp с MaterialApp.router
lib/src/app/router/...     GoRouter routes: /, /settings, /moments/new, /moments/:momentId
lib/src/app/theme/...      AppTheme light/dark
lib/src/app/theme/...      ThemeModeController
lib/src/app/localization   LocaleController, context.l10n
lib/src/app/config         AppConfig
lib/src/app/bootstrap      Supabase initialization
lib/src/generated/l10n     generated AppLocalizations
lib/l10n                   ARB-файлы EN/RU/ES
lib/src/core/backend       supabaseClientProvider
lib/src/core/ui/...        AppSpacing, AppRadius, AppBreakpoints
lib/src/features/auth      AuthScreen, AuthRepository, AppUser, auth providers
lib/src/features/map/...   Mapbox MapScreen, MapboxMapPanel, location permission, marker/list preview bottom sheet
lib/src/features/moments   Moment entity, DTO, repository, providers, NearbyMomentsList, MomentPreviewCard, MomentDetailsScreen/details widgets, create draft/media picker flow, upload/save flow; глава 11 добавит likes
lib/src/features/settings  SettingsScreen с ThemeModeSelector и LocaleSelector
pubspec.yaml               flutter_riverpod, go_router, flutter_localizations, intl, supabase_flutter, flutter_dotenv, mapbox_maps_flutter, permission_handler, image_picker подключены
supabase/migrations        profiles/moments schema, RLS, nearby_moments RPC, seed moments
docs/course/...            документация курса
```

## Команды проверки

```bash
flutter analyze
flutter test
flutter run
```
