# 01 Project Foundation

Статус: done.

## Что строим в этой главе

Мы убираем стандартное counter-приложение и собираем первый настоящий каркас Geo Moments.

После главы приложение еще не будет иметь карту, backend или авторизацию. Но у него уже будет фундамент, на который удобно и безопасно навешивать все следующие функции:

- единая точка входа `main.dart`;
- root widget приложения `GeoMomentsApp`;
- Riverpod scope для будущего state management;
- декларативный router вместо `home`;
- отдельный файл с темами;
- первые два экрана: карта-заглушка и настройки-заглушка;
- понятная структура `lib/src/...`.

Главная мысль главы: мы не "рисуем первый экран", а создаем каркас приложения.

## Почему это важно

Во Flutter очень легко начать писать все в `main.dart`. Для учебного счетчика это нормально, для приложения с auth, картой, Supabase, Firebase, локализацией и релизными сборками - нет.

Если оставить все в одном файле, через несколько глав появятся проблемы:

- router начнет смешиваться с UI;
- настройки темы и языка окажутся в случайных widgets;
- auth redirect будет трудно добавить;
- тесты будут зависеть от настоящего backend;
- экран карты станет слишком большим.

Поэтому первый урок создает структуру заранее, но без лишней сложности.

## Словарь главы

`main.dart` - техническая точка входа. Здесь запускаем Flutter-приложение и подключаем root dependencies.

`ProviderScope` - корневой контейнер Riverpod. Без него providers не работают.

`GeoMomentsApp` - root widget приложения. Здесь живут `MaterialApp.router`, тема, router, позже локализация.

`MaterialApp.router` - вариант `MaterialApp`, который работает не через один `home`, а через навигационный router.

`GoRouter` - объект, который знает список routes и решает, какой экран показать для текущего URL/path.

`ThemeData` - описание визуальной темы Flutter Material UI: цвета, typography, форма кнопок, app bars, scaffold background.

`ColorScheme` - набор цветов Material 3: primary, secondary, surface, error и т.д.

`ConsumerWidget` - Riverpod-версия `StatelessWidget`, внутри которой можно читать providers через `WidgetRef`.

## 1. Что такое `MaterialApp`

Почти любое Flutter Material-приложение имеет наверху `MaterialApp`.

Он отвечает за вещи уровня приложения:

- навигация;
- тема;
- локализация;
- title приложения;
- text direction;
- базовые Material-настройки;
- overlay, dialogs, snack bars, routes.

В шаблонном проекте обычно есть так:

```dart
return MaterialApp(
  title: 'Flutter Demo',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  ),
  home: const MyHomePage(title: 'Flutter Demo Home Page'),
);
```

Поле `home` говорит: "всегда открывай вот этот один стартовый экран".

Для counter-примера этого достаточно. Для Geo Moments недостаточно, потому что у нас будут маршруты:

```text
/
/settings
/auth
/moments/new
/moments/:id
/profile/:id
```

Еще позже появятся:

- auth redirect: если не вошел, отправить на `/auth`;
- deep link: открыть `/moments/123`;
- push notification tap: открыть конкретный момент;
- разные layouts для телефона/планшета.

Для этого нужен router.

## 2. Что такое `MaterialApp.router`

`MaterialApp.router` - это constructor `MaterialApp`, который вместо `home` принимает `routerConfig`.

Сравнение:

```dart
// Просто: один стартовый экран.
MaterialApp(
  home: const MapScreen(),
);
```

```dart
// Масштабируемо: приложением управляет router.
MaterialApp.router(
  routerConfig: router,
);
```

Когда используется `MaterialApp.router`, мы не передаем `home`. Экран выбирается router-ом.

Минимальный пример:

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MapScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

return MaterialApp.router(
  title: 'Geo Moments',
  routerConfig: router,
);
```

Как это работает:

1. Приложение стартует.
2. `MaterialApp.router` спрашивает `GoRouter`: "какой экран показать для текущего path?"
3. Для `/` router строит `MapScreen`.
4. Если вызвать `context.push('/settings')`, router кладет `SettingsScreen` поверх текущего экрана.
5. Системная Back-кнопка снимает верхний экран и возвращает пользователя на карту.

Важно различать два способа перехода:

```dart
context.go('/settings');   // заменить текущую location
context.push('/settings'); // открыть новый экран поверх текущего
```

Для кнопки Settings в app bar нам нужен `push`, потому что пользователь ожидает вернуться назад на карту. Для auth redirect позже чаще будет использоваться `go`, потому что экран авторизации должен заменить недоступный экран, а не лечь поверх него.

## 3. Почему router делаем через Riverpod provider

Можно создать router просто как global variable:

```dart
final router = GoRouter(...);
```

Но в нашем приложении router позже будет зависеть от auth state:

```text
если сессии нет -> /auth
если сессия есть -> /map
если пользователь нажал push -> /moments/:id
```

Поэтому мы сразу кладем router в Riverpod provider:

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
```

Пока provider не делает ничего сложного. Но позже он сможет читать auth provider:

```dart
final authState = ref.watch(authStateProvider);
```

И на основе этого делать redirect.

## 4. Что такое `ProviderScope`

Riverpod хранит providers не в `BuildContext`, а в отдельном контейнере. `ProviderScope` создает этот контейнер.

Он должен быть выше widgets, которые используют Riverpod:

```dart
void main() {
  runApp(
    const ProviderScope(
      child: GeoMomentsApp(),
    ),
  );
}
```

Если забыть `ProviderScope`, приложение с Riverpod упадет во время выполнения, когда кто-то попробует прочитать provider.

В Android-терминах можно думать так:

- `main.dart` похож на место, где мы поднимаем app-level dependencies;
- `ProviderScope` похож на корневой DI container;
- providers похожи на зависимости/state holders, доступные из UI.

Это не точная аналогия с Dagger/Hilt, но направление мысли близкое.

## 5. `StatelessWidget` vs `ConsumerWidget`

Обычный `StatelessWidget`:

```dart
class GeoMomentsApp extends StatelessWidget {
  const GeoMomentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
```

`ConsumerWidget` почти такой же, но получает `WidgetRef`:

```dart
class GeoMomentsApp extends ConsumerWidget {
  const GeoMomentsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      routerConfig: router,
    );
  }
}
```

`WidgetRef` нужен, чтобы читать providers:

- `ref.watch(provider)` - подписаться на provider и перестроиться при изменении;
- `ref.read(provider)` - прочитать один раз, обычно для action/callback;
- `ref.listen(provider, ...)` - реагировать на изменения side-effect-ом.

В этой главе нам нужен `ref.watch(appRouterProvider)`, потому что router лежит в provider.

## 6. Что такое `ThemeData` и `AppTheme`

Flutter Material UI берет цвета и стили из `ThemeData`.

Например, если в `MaterialApp` задана тема:

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
),
```

то widgets вроде `AppBar`, `FloatingActionButton`, `FilledButton`, `Switch`, `TextButton` будут автоматически брать согласованные цвета.

В плохом варианте цвета размазываются по приложению:

```dart
AppBar(backgroundColor: Colors.green)
Container(color: Colors.black)
Text(style: TextStyle(color: Colors.white))
```

В хорошем варианте большинство UI берет значения из темы:

```dart
final colorScheme = Theme.of(context).colorScheme;

Container(
  color: colorScheme.surface,
  child: Text(
    'Geo Moments',
    style: Theme.of(context).textTheme.titleLarge,
  ),
);
```

Так мы сможем централизованно сделать light/dark theme.

## 7. Light и dark theme

У `MaterialApp` есть несколько связанных параметров:

```dart
MaterialApp.router(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: ThemeMode.system,
  routerConfig: router,
);
```

Что означает каждый:

- `theme` - светлая тема;
- `darkTheme` - темная тема;
- `themeMode` - какую тему использовать сейчас;
- `ThemeMode.system` - брать режим из системы;
- `ThemeMode.light` - всегда светлая;
- `ThemeMode.dark` - всегда темная.

В первой главе можно поставить `ThemeMode.system`. Переключатель темы сделаем в следующей главе.

`AppTheme` - это наш класс-обертка, чтобы тема не жила внутри `app.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D6B),
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D6B),
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }
}
```

Почему `abstract final class`:

- `abstract` запрещает создать экземпляр `AppTheme`;
- `final` запрещает наследоваться;
- по сути это namespace для static members.

Можно было бы использовать обычный `class AppTheme`, но в современном Dart такой вариант лучше выражает намерение: это не объект, а набор статических настроек.

## 8. Почему новые файлы могут не влиять на сборку

Если создать файл:

```text
lib/src/app/app.dart
```

но нигде его не импортировать, Flutter о нем не узнает.

Dart компилирует дерево импортов, начиная с entrypoint:

```text
lib/main.dart
  imports app.dart
    imports app_router.dart
      imports map_screen.dart
      imports settings_screen.dart
```

Если `main.dart` все еще содержит старый `GeoMomentsApp` с counter UI, то приложение продолжит запускать counter, даже если рядом лежат новые файлы.

Поэтому практический пункт 3 не "просто переписать main.dart", а переключить entrypoint на новый app root.

## Целевая структура после главы

```text
lib/
  main.dart
  src/
    app/
      app.dart
      router/
        app_router.dart
      theme/
        app_theme.dart
    features/
      map/
        presentation/
          screens/
            map_screen.dart
      settings/
        presentation/
          screens/
            settings_screen.dart
```

## Практика

### Шаг 1. Добавить зависимости

```bash
flutter pub add flutter_riverpod go_router
```

Проверить `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.3.1
  go_router: ^17.2.2
```

Версии могут отличаться. Это нормально, если `flutter pub get` прошел успешно.

### Шаг 2. Создать файлы

Создать структуру из раздела выше.

Важно: пустые файлы - это только подготовка. Приложение изменится только после того, как мы добавим код и импорты.

### Шаг 3. Переписать `main.dart`

Файл `lib/main.dart` должен стать маленьким:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: GeoMomentsApp(),
    ),
  );
}
```

Что здесь происходит:

1. `main()` - стартовая функция Dart-приложения.
2. `runApp(...)` передает Flutter root widget.
3. `ProviderScope` включает Riverpod.
4. `GeoMomentsApp` - наше приложение.

Почему мы больше не держим `GeoMomentsApp` в `main.dart`: `main.dart` должен быть entrypoint, а не местом, где растет весь UI.

### Шаг 4. Создать `GeoMomentsApp`

Файл `lib/src/app/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class GeoMomentsApp extends ConsumerWidget {
  const GeoMomentsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Geo Moments',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
```

Разбор:

- `ConsumerWidget` нужен, потому что читаем `appRouterProvider`;
- `title` используется системой, task switcher и web metadata;
- `debugShowCheckedModeBanner: false` убирает debug-плашку;
- `theme` и `darkTheme` подключают наши темы;
- `themeMode: ThemeMode.system` пока доверяет системной теме;
- `routerConfig` подключает `GoRouter`.

### Шаг 5. Создать темы

Файл `lib/src/app/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF2E7D6B);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return _themeFrom(colorScheme);
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return _themeFrom(colorScheme);
  }

  static ThemeData _themeFrom(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
    );
  }
}
```

На этом этапе не нужно делать идеальный дизайн. Нам нужен правильный механизм.

### Шаг 6. Создать router

Файл `lib/src/app/router/app_router.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

abstract final class AppRoutePaths {
  static const map = '/';
  static const settings = '/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutePaths.map,
    routes: [
      GoRoute(
        path: AppRoutePaths.map,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
```

Зачем `AppRoutePaths`:

- меньше строковых литералов по проекту;
- проще переименовать route;
- меньше опечаток.

Позже можно будет добавить route names, typed routes или code generation, но сейчас это лишнее.

### Шаг 7. Создать `MapScreen`

Файл `lib/src/features/map/presentation/screens/map_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Moments'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: const Center(
              child: Text('Map placeholder'),
            ),
          ),
        ),
      ),
    );
  }
}
```

Что здесь важно:

- экран пока dumb UI, без business logic;
- переход в settings идет через `context.push(...)`, чтобы системная Back-кнопка вернула пользователя на карту;
- цвета берутся из темы, не из случайных `Colors.*`;
- `SafeArea` защищает контент от status bar/notch/system gestures;
- placeholder занимает место будущей карты.

### Шаг 8. Создать `SettingsScreen`

Файл `lib/src/features/settings/presentation/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const SafeArea(
        child: Center(
          child: Text('Settings placeholder'),
        ),
      ),
    );
  }
}
```

Пока настройки пустые. В следующих главах сюда попадут:

- theme mode;
- language;
- profile/account actions;
- notification permissions.

### Шаг 9. Обновить widget test

Старый тест ищет counter. После удаления counter-template он должен быть заменен.

Файл `test/widget_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:geo_moments/src/app/app.dart';

void main() {
  testWidgets('shows map screen on app start', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GeoMomentsApp(),
      ),
    );

    expect(find.text('Geo Moments'), findsOneWidget);
    expect(find.text('Map placeholder'), findsOneWidget);
  });
}
```

Почему в тесте тоже нужен `ProviderScope`: тест запускает app widget напрямую, без `main()`.

## Проверка

Запустить:

```bash
flutter analyze
flutter test
```

Ожидаемый результат:

```text
No issues found!
All tests passed!
```

Потом можно запустить приложение:

```bash
flutter run
```

Ручная проверка:

1. На старте виден экран `Geo Moments`.
2. Видна область `Map placeholder`.
3. Кнопка settings открывает экран `Settings`.
4. Back возвращает на главный экран.
5. При смене системной темы приложение выглядит темным/светлым.

## Частые ошибки

### Ошибка: создал `app.dart`, но запускается старый counter

Причина: `main.dart` все еще содержит старый `GeoMomentsApp` или не импортирует `src/app/app.dart`.

Решение: оставить в `main.dart` только маленький entrypoint из шага 3.

### Ошибка: `ProviderScope` missing

Причина: где-то запускается `GeoMomentsApp` без `ProviderScope`.

Решение: обернуть app в `ProviderScope`, в том числе в widget tests.

### Ошибка: системная Back-кнопка закрывает приложение вместо возврата на карту

Причина: для перехода с карты в настройки использован `context.go(...)`. Он заменяет текущую location и не создает ожидаемый экран в back stack.

Решение: для app bar settings button использовать:

```dart
context.push(AppRoutePaths.settings)
```

`context.go(...)` оставим для случаев, где нужно заменить текущий route: auth redirect, logout, переключение корневых разделов.

### Ошибка: `No GoRouter found in context`

Причина: экран с `context.push(...)` тестируется без `MaterialApp.router`/router.

Решение: в обычном app flow экран должен строиться через `GeoMomentsApp`. Для изолированных widget tests позже будем использовать test router или mock shell.

### Ошибка: импорт с большим количеством `../../../../`

На старте это допустимо. Позже обсудим `package:` imports и analyzer rule для единообразия.

## Definition of Done

- В `main.dart` нет counter-template.
- `GeoMomentsApp` находится в `lib/src/app/app.dart`.
- Используется `ProviderScope`.
- Используется `MaterialApp.router`.
- Router объявлен в `appRouterProvider`.
- Есть route `/` и `/settings`.
- Light/dark theme вынесены в `AppTheme`.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Приложение можно запустить и вручную перейти на settings screen.

## Что прислать на ревью

После выполнения главы напиши:

```text
Глава 1 готова, проверь код.
```

Я проверю:

- соответствует ли структура цели главы;
- нет ли старого counter-кода;
- не смешались ли router/theme/UI в одном месте;
- корректно ли используются Riverpod и `MaterialApp.router`;
- проходят ли анализатор и тесты.

Если будет ошибка, разберем ее как учебный материал, а не просто "починим строку".
