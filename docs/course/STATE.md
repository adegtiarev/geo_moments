# Course State

Последнее обновление: 2026-04-29

## Статус

Текущая стадия: `03-localization`

Глава 2 завершена и закоммичена. Проект имеет базовый Flutter-каркас с Riverpod, `MaterialApp.router`, `go_router`, light/dark theme, ручным переключателем темы, design tokens, responsive map placeholder layout и widget previews для map feature components.

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

## Следующая глава

Текущая глава: [03 Localization](lessons/03-localization.md)

Цель главы: добавить полноценную локализацию UI на английский, русский и испанский:

- подключить `flutter_localizations` и `intl`;
- настроить `gen-l10n` через `l10n.yaml`;
- добавить ARB-файлы `en`, `ru`, `es`;
- заменить hardcoded UI text на `AppLocalizations`;
- добавить ручное переключение языка в settings;
- сохранить проект в рабочем состоянии;
- проверка `flutter analyze`, `flutter test` и ручная проверка переключения языка.

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
lib/src/core/ui/...        AppSpacing, AppRadius, AppBreakpoints
lib/src/features/map/...   responsive MapScreen, MapPlaceholderPanel, previews
lib/src/features/settings  SettingsScreen с ThemeModeSelector
pubspec.yaml               flutter_riverpod и go_router подключены
docs/course/...            документация курса
```

## Команды проверки

```bash
flutter analyze
flutter test
flutter run
```
