# Course State

Последнее обновление: 2026-05-10

## Статус

Текущая стадия: `course-complete`

Глава 18 завершена пользователем и проверена в этом чате. Проект имеет базовый Flutter-каркас с Riverpod, `MaterialApp.router`, `go_router`, light/dark theme, ручным переключателем темы, design tokens, локализацию EN/RU/ES, Supabase bootstrap/config foundation, auth flow через Supabase OAuth, SQL migrations для `profiles`/`moments`, RLS policies, `moment-media` bucket и storage policies, seed data, Flutter domain/data/presentation layer для чтения moments из Supabase, настоящий Mapbox map screen с markers, responsive layout, location permission, marker/list preview bottom sheet на compact phone, wide/tablet side detail panel, details route `/moments/:momentId`, create route `/moments/new` с настоящим upload/save flow, likes flow для moments, comments/replies flow с Supabase Realtime, Firebase/FCM push notifications для новых comments/replies, reliability layer для lifecycle, permissions, retry, failures и logging, Drift/SQLite read-side cache для nearby moments/details с stale-while-revalidate flow, выделенные test helpers и quality gate в README, а также release-ready Android/iOS assets, signing/checklist documentation и Android release artifacts.

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
- Реализована глава 11: добавлены `moment_likes`, RLS policies, `moment_like_summary`, `like_moment`, `unlike_moment`, `MomentLikeSummary`, `MomentLikesRepository`, `SupabaseMomentLikesRepository`, `MomentLikeController`, `MomentLikeButton`.
- Likes работают через idempotent commands, optimistic update, disabled button while busy и rollback при backend error.
- `nearby_moments` обновлен для `like_count`; новая likes migration также переопределяет function, потому что уже примененные старые migrations не переисполняются.
- Details стал устойчивее: если embedded `profiles(...)` не проходит, moment загружается fallback-запросом, а author profile дочитывается отдельно.
- Исправлена синхронизация имени профиля: `SupabaseAuthRepository` обновляет `profiles.display_name/avatar_url` из Auth metadata; migration `202605090002_sync_profile_names_from_auth.sql` обновляет trigger и существующие profiles.
- Убран UUID из details UI: автор показывается только как display name, а не raw id.
- Добавлены tests для like controller и widget test details с fake likes repository через provider override.
- Пользователь проверил вручную: details открываются, likes ставятся/убираются, имя автора совпадает с именем пользователя после sync profiles.
- Проверки после главы 11 проходили 2026-05-09: `flutter gen-l10n`, `flutter analyze`, `flutter test`.
- Реализована глава 12: добавлена migration `202605090003_create_moment_comments.sql`, таблица `moment_comments`, RLS policies, trigger `validate_moment_comment_parent` для ограничения replies одним уровнем, Supabase Realtime publication для `public.moment_comments`.
- Добавлены RPC `moment_comments_page`, `create_moment_comment`, `moment_comment_count`; `nearby_moments` переопределен так, чтобы возвращать настоящий `comment_count`.
- Добавлены `MomentComment`, `CreateCommentCommand`, `MomentCommentDto`, `MomentCommentsRepository`, `SupabaseMomentCommentsRepository`, `MomentCommentsController`.
- Details показывает comments section, comment input, reply mode и обновляет comments через realtime refresh открытого обсуждения.
- Widget tests продолжают учитывать scrollable details; `test/moment_comments_controller_test.dart` использует fake repository через provider overrides и проверяет root comment, reply и rollback state при ошибке.
- Перед главой 13 исправлен fallback автора в comments UI: если `authorDisplayName` отсутствует, raw UUID автора не показывается.
- Пользователь сообщил, что Supabase migration применена, RLS включен, replies связаны через `parent_id`, realtime publication проверена через `pg_publication_tables`, details/likes/comments/replies работают вручную.
- Проверки после главы 12 в этом чате прошли 2026-05-09: `flutter analyze`, `flutter test`.
- Реализована глава 13: добавлены Firebase config files `firebase.json`, `android/app/google-services.json`, `lib/firebase_options.dart`, зависимости `firebase_core`/`firebase_messaging`, Firebase initialization и top-level background handler в bootstrap.
- Добавлена migration `202605100001_create_push_tokens.sql`: таблица `push_tokens`, RLS policies, `upsert_push_token` через `auth.uid()` и unique token для multi-device token storage.
- Добавлена feature `lib/src/features/notifications`: `PushMessagingClient`, `FirebasePushMessagingClient`, `PushTokensRepository`, `SupabasePushTokensRepository`, `PushNotificationsController`, `NotificationStatusTile`.
- Settings стал показывать notification status/action; permission dialog вызывается по действию пользователя, а token registration происходит только для signed-in user при authorized/provisional status.
- `GeoMomentsApp` слушает `FirebaseMessaging.onMessageOpenedApp`, проверяет `getInitialMessage()` и открывает `/moments/:momentId` по data payload `moment_id`; pending notification moment открывается после auth state.
- Добавлена Edge Function `supabase/functions/send-comment-push/index.ts`, вызываемая Database Webhook на `moment_comments insert`; function проверяет `x-webhook-secret`, находит recipient для root comment/reply, не отправляет push автору собственного действия, отправляет FCM HTTP v1 message и чистит invalid FCM tokens.
- Firebase service account JSON не закоммичен; Supabase использует secret `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`, `COMMENT_PUSH_WEBHOOK_SECRET` сохранен в Supabase secrets, function задеплоена с `--no-verify-jwt` и собственной проверкой webhook secret.
- Пользователь проверил вручную push на реальном устройстве и эмуляторе под разными аккаунтами; последний проверочный ответ Edge Function был `{"sent":1,"failed":1,"removed_invalid_tokens":1}`, после cleanup ожидается `failed:0`.
- Проверено 2026-05-10: `flutter gen-l10n`, `flutter analyze`, `flutter test`. Перед обновлением course docs `git status --short` был чистым. Поиск по репозиторию не нашел закоммиченный Firebase service account/private key, кроме безопасных упоминаний в Edge Function и уроке.
- Реализована глава 14: добавлены `AppLifecycleService`, `appLifecycleServiceProvider`, `appResumedProvider`, refresh location permission на resume и refresh push permission без повторного permission dialog.
- Добавлены локализованные EN/RU/ES строки для permission banner, retry titles и offline/timeout/generic failure messages; hardcoded UI strings из widgets убраны.
- Добавлены `LocationPermissionBanner`, `RetryErrorView`, `AppFailure`, `messageForFailure`, `RetryPolicy`, `AppLogger`, `DebugAppLogger`, `appLoggerProvider`.
- `MapScreen` показывает location permission banner, открывает system settings для permanently denied/restricted, сохраняет focus command для location button и показывает retry UI при первом failure загрузки nearby moments.
- `MomentDetailsScreen` и comments section в `MomentDetailsContent` показывают localized retry UI; `MomentCommentsController.retry()` инвалидирует текущий family provider без ручного параллельного state.
- `nearbyMomentsProvider`, `momentDetailsProvider` и comments fetch используют `RetryPolicy` timeout.
- Push/create logging переведен с прямого `debugPrint` на `AppLogger`; FCM token логируется только коротким prefix.
- Добавлен `test/app_lifecycle_test.dart` с реальным `main()` и fake lifecycle service через provider override.
- Проверено после главы 14 2026-05-10: `flutter gen-l10n`, `dart format lib test`, `flutter analyze`, `flutter test`.
- Реализована глава 15: `AppBreakpoints` расширен до window class и `useSidePanel`, `MapScreen` хранит выбранный moment и выбирает tap handler по layout.
- Compact phone layout сохраняет bottom sheet preview и route `/moments/:momentId`; tablet/wide landscape показывает карту и side panel рядом.
- Добавлен `MomentDetailsPane`, который использует существующий `momentDetailsProvider` и `MomentDetailsContent`, поэтому details route, fallback optional profile/RPC и scrollable comments не дублируются.
- `MomentMediaView` получил стабильный `AspectRatio`, `maxHeight` и localized semantics labels для image/video/missing media.
- Добавлены EN/RU/ES строки для selected moment panel, close tooltip, map semantics и media semantics.
- Widget tests покрывают tablet side panel, compact phone preview sheet, semantic label карты и продолжают использовать fake map/provider overrides.
- Route order `/moments/new` перед `/moments/:momentId` сохранен; location button по-прежнему отправляет focus command карте.
- Проверено после главы 15 2026-05-10: `flutter gen-l10n`, `dart format lib test docs/course`, `flutter analyze`, `flutter test`.
- Реализована глава 16: добавлены зависимости `drift`, `drift_flutter`, `path_provider`, `drift_dev`, `build_runner`.
- Добавлены `lib/src/core/database/app_database.dart` и generated `app_database.g.dart`; локальная таблица `CachedMoments` использует getter `body` с SQL name `text`, чтобы не конфликтовать с `Table.text()`.
- Добавлен `MomentsCache` с `readNearbyMoments`, `readMomentById`, `replaceNearbyMoments` и `upsertMoment`, который маппит Drift rows обратно в domain `Moment`.
- `nearbyMomentsProvider` переведен на Riverpod 3 `AsyncNotifierProvider.family`; family argument `MapCameraCenter` передается в constructor `NearbyMomentsController`.
- Nearby moments используют stale-while-revalidate: сначала читают cache, затем фоном обновляются из Supabase и записывают fresh data в cache; remote failure не стирает уже показанный cache.
- `momentDetailsProvider` переведен на `MomentDetailsController`: details открываются из cache без ожидания remote, а fresh remote details обновляют cache.
- `CreateMomentSaveController` записывает успешно созданный moment в cache и логирует cache-write failure без отката успешного backend insert.
- `SupabaseAuthRepository.watchCurrentUser()` больше не блокирует offline startup на `_syncProfile`; transient null session не выбрасывает пользователя на login, а явный signed out обрабатывается отдельно.
- Добавлены tests `moments_cache_test.dart`, `nearby_moments_cache_test.dart`, `moment_details_cache_test.dart`; widget tests используют in-memory Drift database и fake repository overrides.
- Старые Supabase migration-файлы не менялись для локального cache; route order `/moments/new` перед `/moments/:momentId`, compact bottom sheet preview, tablet/wide side panel и location focus behavior сохранены.
- Проверено после главы 16 2026-05-10: `dart run build_runner build`, `flutter gen-l10n`, `dart format lib test docs/course`, `flutter analyze`, `flutter test` прошли. После проверки `git status --short` был чистым.
- Реализована глава 17: общие fake repositories, test data и `pumpGeoMomentsTestApp` вынесены в `test/helpers`.
- `widget_test.dart` стал сценарным и использует общий helper вместо локального набора fake classes.
- Добавлены/сохранены regression tests для compact bottom sheet preview, tablet side panel, route order `/moments/new` перед `/moments/:momentId`, notification tap details route, location focus command и semantics label карты.
- Cache provider tests усилены сценариями stale cache -> remote refresh для nearby moments и details; tests используют `Completer` и `container.listen`, а не произвольные задержки.
- `README.md` дополнен quality gate командами, Drift/SQLite cache в стеке и предупреждением не коммитить `.env`, Firebase service account JSON или service role secrets.
- Во время проверки исправлено: test `cached details remain visible when comments are unavailable` теперь явно выставляет compact phone viewport перед ожиданием bottom sheet; удалены duplicate imports в cache tests; semantics test теперь закрывает `SemanticsHandle` внутри body теста.
- Проверено после главы 17 2026-05-10: `dart run build_runner build`, `flutter gen-l10n`, `dart format lib test docs/course`, `flutter analyze`, `flutter test` прошли.
- Реализована глава 18: добавлены `flutter_launcher_icons` и `flutter_native_splash`, source assets `assets/branding/app_icon.png` и `assets/branding/splash_icon.png`, generated Android/iOS launcher icons и splash assets.
- Android app label изменен на `Geo Moments`; Supabase OAuth deep link `io.supabase.geomoments://login-callback/` сохранен.
- Android release signing переведен на `android/key.properties` с fallback на debug signing только для учебной/CI сборки без локальных secrets; template `android/key.properties.example` добавлен без реальных secrets.
- `.gitignore` теперь игнорирует `.env`, `.env.*`, `android/key.properties`, `*.jks`, `*.keystore`, но сохраняет `.env.example`.
- Добавлены release checklists `docs/release/android-release-checklist.md` и `docs/release/ios-release-checklist.md`; README дополнен features, architecture, development checks и release links.
- Во время проверки исправлено: `.env.production` и другие `.env.*` теперь защищены от случайного commit; из Gradle удалены template TODO comments; Android checklist явно предупреждает не публиковать artifacts, подписанные debug fallback.
- Проверено после главы 18 2026-05-10: `dart run build_runner build`, `flutter gen-l10n`, `dart format lib test docs/course`, `flutter analyze`, `flutter test`, `flutter build appbundle --release`, `flutter build apk --release --split-per-abi` прошли.
- Android release artifacts собраны локально: `build/app/outputs/bundle/release/app-release.aab`, `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`.

## Следующая глава

Текущая глава: курс завершен

Следующий возможный этап вне курса:

- ручной release smoke test на реальном Android device;
- TestFlight/iOS проверка на macOS;
- настройка production Firebase/Supabase проектов и OAuth fingerprints;
- публикация portfolio README/screenshots;
- отдельный future PR для flavors, если нужны dev/prod apps на одном устройстве.

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
lib/src/core/database      Drift AppDatabase, CachedMoments table, generated app_database.g.dart
lib/src/core/lifecycle     app lifecycle service/providers
lib/src/core/logging       AppLogger, DebugAppLogger, appLoggerProvider
lib/src/core/network       AppFailure, localized failure messages, RetryPolicy
lib/src/core/ui/...        AppSpacing, AppRadius, AppBreakpoints
lib/src/features/auth      AuthScreen, AuthRepository, AppUser, auth providers
lib/src/features/map/...   Mapbox MapScreen, MapboxMapPanel, location permission, marker/list preview bottom sheet
lib/src/features/moments   Moment entity, DTO, repository, providers, NearbyMomentsList, MomentPreviewCard, MomentDetailsScreen/details widgets, create draft/media picker flow, upload/save flow, likes flow, comments/replies flow
lib/src/features/moments/data/local   MomentsCache для Drift read-side cache
lib/src/features/notifications   FCM token registration, permission controller, notification tap routing, Settings notification tile
lib/src/features/settings  SettingsScreen с ThemeModeSelector и LocaleSelector
pubspec.yaml               flutter_riverpod, go_router, flutter_localizations, intl, supabase_flutter, flutter_dotenv, mapbox_maps_flutter, permission_handler, image_picker, firebase_core, firebase_messaging, drift, drift_flutter, path_provider, drift_dev, build_runner подключены
supabase/migrations        profiles/moments schema, RLS, nearby_moments RPC, seed moments, moment_likes, moment_comments, push_tokens
supabase/functions         send-comment-push Edge Function для FCM HTTP v1 push по comments/replies
docs/course/...            документация курса
docs/release/...           Android/iOS release checklists
assets/branding/...        source PNG для launcher icon и splash
```

## Команды проверки

```bash
flutter analyze
flutter test
flutter run
```
