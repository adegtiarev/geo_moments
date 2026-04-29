# Course State

Последнее обновление: 2026-04-29

## Статус

Текущая стадия: `02-design-system-theme-responsive-basics`

Глава 1 завершена и закоммичена. Проект имеет базовый Flutter-каркас с Riverpod, `MaterialApp.router`, `go_router`, light/dark theme и двумя экранами: map placeholder и settings placeholder.

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

## Следующая глава

Текущая глава: [02 Design System, Theme, Responsive Basics](lessons/02-design-system-theme-responsive-basics.md)

Цель главы: превратить базовые темы и placeholder UI в управляемую дизайн-основу приложения:

- добавить `ThemeMode` state через Riverpod;
- сделать ручное переключение light/dark/system в settings;
- выделить design tokens: spacing, radius, breakpoints;
- сделать главный экран адаптивным для phone/tablet и portrait/landscape;
- сохранить проект в рабочем состоянии;
- проверка `flutter analyze` и запуск.

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
lib/src/features/map/...   MapScreen с placeholder и переходом в settings через push
lib/src/features/settings  SettingsScreen placeholder
pubspec.yaml               flutter_riverpod и go_router подключены
docs/course/...            документация курса
```

## Команды проверки

```bash
flutter analyze
flutter test
flutter run
```
