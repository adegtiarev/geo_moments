# Course State

Последнее обновление: 2026-04-29

## Статус

Текущая стадия: `05-auth-and-profiles`

Глава 4 завершена и закоммичена. Проект имеет базовый Flutter-каркас с Riverpod, `MaterialApp.router`, `go_router`, light/dark theme, ручным переключателем темы, design tokens, responsive map placeholder layout, widget previews, локализацию EN/RU/ES, ручной переключатель языка и Supabase bootstrap/config foundation.

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

## Следующая глава

Текущая глава: [05 Auth and Profiles](lessons/05-auth-and-profiles.md)

Цель главы: добавить первый полноценный auth flow и базовую модель профиля без сложной бизнес-логики:

- настроить redirect URLs для Supabase OAuth;
- добавить auth state stream через Riverpod;
- добавить `AuthScreen`;
- добавить вход через Google OAuth для Android/dev;
- подготовить кнопку/ветку Apple OAuth для iOS;
- добавить auth gate в router;
- показать signed-in user в Settings;
- добавить sign out;
- сохранить проект в рабочем состоянии;
- проверка `flutter analyze`, `flutter test`, ручная проверка sign in/out.

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
lib/src/app/router/...     GoRouter routes: / и /settings
lib/src/app/theme/...      AppTheme light/dark
lib/src/app/theme/...      ThemeModeController
lib/src/app/localization   LocaleController, context.l10n
lib/src/app/config         AppConfig
lib/src/app/bootstrap      Supabase initialization
lib/src/generated/l10n     generated AppLocalizations
lib/l10n                   ARB-файлы EN/RU/ES
lib/src/core/backend       supabaseClientProvider
lib/src/core/ui/...        AppSpacing, AppRadius, AppBreakpoints
lib/src/features/map/...   responsive MapScreen, MapPlaceholderPanel, previews
lib/src/features/settings  SettingsScreen с ThemeModeSelector и LocaleSelector
pubspec.yaml               flutter_riverpod, go_router, flutter_localizations, intl, supabase_flutter, flutter_dotenv подключены
docs/course/...            документация курса
```

## Команды проверки

```bash
flutter analyze
flutter test
flutter run
```
