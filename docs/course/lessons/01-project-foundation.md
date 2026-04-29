# 01 Project Foundation

Статус: next.

## Цель главы

Поменять стандартный counter-template на минимальный каркас Geo Moments, который уже похож на настоящее приложение и не развалится при росте features.

После главы проект должен:

- запускаться на Android/iOS;
- иметь `ProviderScope`;
- использовать `MaterialApp.router`;
- иметь базовую навигацию;
- иметь стартовую структуру `lib/src`;
- проходить `flutter analyze` и `flutter test`.

## Теория

### 1. Flutter app root

В простом шаблоне `main.dart` сразу вызывает `runApp(MyApp())`. В production-проекте лучше разделить:

- bootstrap: подготовка Flutter bindings, env, логирования, backend SDK;
- app widget: MaterialApp, router, theme, localization;
- features: экраны и бизнес-логика.

На первой главе bootstrap будет минимальным, но место под него создадим сразу.

### 2. Riverpod at the root

Riverpod подключается через `ProviderScope` над приложением:

```dart
void main() {
  runApp(const ProviderScope(child: GeoMomentsApp()));
}
```

Это делает providers доступными всему дереву. В отличие от `Provider` вокруг отдельных экранов, такой root scope удобен для auth state, theme settings, locale settings, repositories и router.

### 3. Router instead of `home`

`MaterialApp(home: ...)` нормален для маленького примера, но для приложения с auth gate, deep links и notification tap лучше сразу использовать `MaterialApp.router`.

Целевой стек:

- `go_router` для route declarations;
- typed route constants;
- auth redirect позже;
- deep links для `/moments/:id` позже.

### 4. Feature-first structure

Мы не раскладываем весь проект по типам вроде `screens/`, `widgets/`, `services/`, потому что при росте приложения это смешивает ответственность. Вместо этого группируем по features:

```text
features/settings/...
features/moments/...
features/auth/...
```

Внутри feature уже появляются `data/domain/presentation`, когда feature становится достаточно большой.

### 5. ConsumerWidget

`ConsumerWidget` - это `StatelessWidget`, которому доступен `WidgetRef`. Через `ref.watch(...)` UI подписывается на state. В первой главе можно почти не использовать state, но root уже будет готов.

## Практическое задание

1. Добавить зависимости:

```bash
flutter pub add flutter_riverpod go_router
```

2. Создать структуру:

```text
lib/
  main.dart
  src/
    app/
      app.dart
      router/app_router.dart
      theme/app_theme.dart
    features/
      map/presentation/screens/map_screen.dart
      settings/presentation/screens/settings_screen.dart
```

3. Переписать `main.dart`:

- импортировать Riverpod;
- вызвать `ProviderScope`;
- запустить `GeoMomentsApp`.

4. Создать `GeoMomentsApp`:

- `MaterialApp.router`;
- title `Geo Moments`;
- light/dark theme из `AppTheme`;
- routerConfig из `appRouterProvider`.

5. Создать routes:

- `/` -> `MapScreen`;
- `/settings` -> `SettingsScreen`.

6. Сделать временный UI:

- `MapScreen`: scaffold с app bar, заголовком Geo Moments, кнопкой перехода в settings, placeholder области карты;
- `SettingsScreen`: scaffold с app bar и placeholder настроек.

## Definition of Done

- Counter-template удален.
- Приложение запускается.
- Есть переход `/settings` и назад.
- `flutter analyze` проходит.
- `flutter test` либо проходит, либо тест шаблона обновлен под новый root app.

## Что я буду проверять в ревью

- Нет ли business logic в widgets.
- Не используется ли `BuildContext` для state там, где нужен provider.
- Не зашиты ли будущие backend/secrets в UI.
- Структура файлов не создает хаоса заранее.
- UI простой, но уже не выглядит как demo-counter.

