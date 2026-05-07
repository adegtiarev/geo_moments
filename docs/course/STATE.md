# Course State

Последнее обновление: 2026-05-07

## Статус

Текущая стадия: `09-create-moment-media-capture`

Глава 8 завершена пользователем и проверена. Проект имеет базовый Flutter-каркас с Riverpod, `MaterialApp.router`, `go_router`, light/dark theme, ручным переключателем темы, design tokens, локализацию EN/RU/ES, Supabase bootstrap/config foundation, auth flow через Supabase OAuth, SQL migrations для `profiles`/`moments`, RLS policies, `moment-media` bucket, seed data, Flutter domain/data/presentation layer для чтения moments из Supabase, настоящий Mapbox map screen с markers, responsive layout, location permission, marker/list preview bottom sheet и details route `/moments/:momentId`.

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

## Следующая глава

Текущая глава: [09 Create Moment: Media Capture](lessons/09-create-moment-media-capture.md)

Цель главы: добавить первый create flow без backend save:

- добавить `image_picker`;
- настроить Android/iOS camera/photo/video permission metadata;
- создать route `/moments/new`;
- открыть create screen из `MapScreen`;
- выбрать фото/видео из gallery;
- снять фото или записать видео через camera;
- держать media/text/emotion как локальный draft в Riverpod `Notifier`;
- спрятать `image_picker` за `MomentMediaPicker`, чтобы UI и tests не зависели от native plugin;
- обработать Android `retrieveLostData()`;
- добавить validation для media + description;
- сохранить tests через provider overrides и без запуска native picker;
- проверка `flutter gen-l10n`, `flutter analyze`, `flutter test`, ручная Android-проверка media picker.

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
lib/src/app/router/...     GoRouter routes: /, /settings, /moments/:momentId; глава 9 добавит /moments/new
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
lib/src/features/moments   Moment entity, DTO, repository, providers, NearbyMomentsList, MomentPreviewCard, MomentDetailsScreen/details widgets; глава 9 добавит create draft/media picker flow
lib/src/features/settings  SettingsScreen с ThemeModeSelector и LocaleSelector
pubspec.yaml               flutter_riverpod, go_router, flutter_localizations, intl, supabase_flutter, flutter_dotenv, mapbox_maps_flutter, permission_handler подключены
supabase/migrations        profiles/moments schema, RLS, nearby_moments RPC, seed moments
docs/course/...            документация курса
```

## Команды проверки

```bash
flutter analyze
flutter test
flutter run
```
