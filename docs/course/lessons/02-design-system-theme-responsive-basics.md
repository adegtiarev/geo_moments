# 02 Design System, Theme, Responsive Basics

Статус: next.

## Что строим в этой главе

В первой главе мы создали каркас приложения. Во второй главе делаем его управляемым визуально:

- добавляем ручное переключение темы: system, light, dark;
- переносим выбор темы в Riverpod state;
- вводим первые design tokens: spacing, radius, breakpoints;
- улучшаем `MapScreen`, чтобы он нормально выглядел на телефоне, планшете, portrait и landscape;
- превращаем `SettingsScreen` из placeholder в первый настоящий экран настроек.

После главы карта все еще будет placeholder. Это нормально. Сейчас мы готовим оболочку, в которую позже вставим Mapbox.

## Почему это важно

Тема и адаптивность лучше заложить рано. Иначе каждый следующий экран начнет сам выбирать отступы, радиусы, цвета и условия для планшета.

В Android legacy это похоже на ситуацию, когда часть цветов лежит в `colors.xml`, часть зашита в layout XML, часть создается в Java-коде. Работает, пока экранов мало. Потом любое изменение темы становится дорогим.

Во Flutter правильный путь такой:

- общие цвета идут через `ThemeData` и `ColorScheme`;
- повторяемые размеры идут через маленькие constants/classes;
- выбор темы хранится как app state;
- экран сам адаптирует layout под доступный размер, а не под конкретную модель устройства.

## Словарь главы

`ThemeMode` - enum Flutter: `system`, `light`, `dark`. Определяет, какую тему использовать.

`Notifier` - Riverpod-класс для state, которым можно управлять методами.

`NotifierProvider` - provider, который создает `Notifier` и отдает наружу его state.

`Design tokens` - маленькие переиспользуемые значения дизайна: отступы, радиусы, breakpoints, durations.

`Breakpoint` - ширина, после которой layout меняет структуру. Например, до 600 dp телефонный layout, от 600 dp планшетный.

`LayoutBuilder` - Flutter widget, который дает constraints родителя. Через него можно строить responsive UI.

`OrientationBuilder` - Flutter widget, который дает текущую ориентацию: portrait или landscape.

`SafeArea` - widget, который не дает контенту залезть под status bar, notch, navigation bar и system gestures.

`SegmentedButton` - Material 3 control для выбора одного или нескольких вариантов из небольшого набора.

## 1. Что такое `ThemeMode`

В первой главе в `GeoMomentsApp` было:

```dart
theme: AppTheme.light,
darkTheme: AppTheme.dark,
themeMode: ThemeMode.system,
```

Это значит:

- светлая тема описана в `AppTheme.light`;
- темная тема описана в `AppTheme.dark`;
- текущий режим берется из системы.

`ThemeMode` имеет три значения:

```dart
ThemeMode.system
ThemeMode.light
ThemeMode.dark
```

Для Geo Moments нам нужен ручной переключатель. Пользователь может захотеть темную тему даже при светлой системной теме, особенно для карты вечером.

Поэтому во второй главе мы убираем hardcoded `ThemeMode.system` и начинаем читать значение из Riverpod.

## 2. Почему state темы хранится в Riverpod

Тема влияет на все приложение. Если хранить ее внутри `SettingsScreen`, то `MaterialApp` не узнает, что тему нужно поменять.

Нам нужен app-level state:

```text
SettingsScreen нажимает "Dark"
  -> ThemeModeController меняет state
  -> GeoMomentsApp watch-ит state
  -> MaterialApp получает ThemeMode.dark
  -> все приложение перестраивается в темной теме
```

Минимальный Riverpod `Notifier`:

```dart
final counterProvider = NotifierProvider<CounterController, int>(
  CounterController.new,
);

class CounterController extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state++;
  }
}
```

Для темы будет то же самое, только state не `int`, а `ThemeMode`:

```dart
final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode themeMode) {
    state = themeMode;
  }
}
```

Пока мы не сохраняем выбор после перезапуска приложения. Это будет позже, когда появится settings persistence. Сейчас цель - понять state flow.

## 3. `ref.watch` и `ref.read` на примере темы

В `GeoMomentsApp` мы хотим подписаться на текущий `ThemeMode`. Если он изменится, приложение должно перестроиться:

```dart
final themeMode = ref.watch(themeModeControllerProvider);
```

В `SettingsScreen` нам нужно:

- показать выбранное значение;
- вызвать метод при выборе нового значения.

Для показа используем `watch`:

```dart
final themeMode = ref.watch(themeModeControllerProvider);
```

Для действия используем `read`:

```dart
ref
    .read(themeModeControllerProvider.notifier)
    .setThemeMode(ThemeMode.dark);
```

Правило:

- `watch` - когда UI зависит от значения и должен обновляться;
- `read` - когда нужно выполнить действие в callback.

## 4. Что такое design tokens

Design tokens - это общие значения дизайна, которые используются во многих местах.

Плохой вариант:

```dart
padding: const EdgeInsets.all(16)
borderRadius: BorderRadius.circular(16)
gap: const SizedBox(height: 12)
```

Если такие числа разбросаны по всему проекту, дизайн быстро становится случайным.

Лучше ввести маленькие классы:

```dart
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
}
```

Это не "дизайн-система уровня корпорации". Это просто способ не плодить магические числа.

## 5. Что такое responsive layout во Flutter

Во Flutter экран строится от constraints.

Родитель говорит ребенку:

```text
можешь занять максимум 390x844
```

или:

```text
можешь занять максимум 1024x768
```

Ребенок решает, как расположить контент.

Для этого используется `LayoutBuilder`:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 600) {
      return const TabletLayout();
    }

    return const PhoneLayout();
  },
)
```

Важно: мы не проверяем "это iPad?" или "это Pixel?". Мы смотрим на доступную ширину.

Базовые breakpoints:

```dart
abstract final class AppBreakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;

  static bool isTablet(double width) => width >= tablet;
}
```

Для Geo Moments:

- телефон portrait: карта placeholder занимает основную область, ниже короткая панель;
- телефон landscape: меньше вертикальных отступов, контент не должен ломаться;
- планшет: можно показать карту placeholder и side panel рядом.

## 6. `LayoutBuilder` vs `MediaQuery`

`MediaQuery.of(context).size` дает размер всего экрана.

`LayoutBuilder` дает размер места, которое выделил родитель.

Для responsive widgets чаще лучше `LayoutBuilder`, потому что widget может жить не на весь экран.

Пример:

```dart
final screenWidth = MediaQuery.sizeOf(context).width;
```

Это ширина всего окна.

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final availableWidth = constraints.maxWidth;
    ...
  },
)
```

Это ширина конкретной области, внутри которой строится widget.

В этой главе используем `LayoutBuilder` на `MapScreen`.

## 7. `SegmentedButton` для выбора темы

Для трех вариантов `System / Light / Dark` хорошо подходит `SegmentedButton`.

Минимальный пример:

```dart
SegmentedButton<ThemeMode>(
  segments: const [
    ButtonSegment(
      value: ThemeMode.system,
      label: Text('System'),
      icon: Icon(Icons.brightness_auto_outlined),
    ),
    ButtonSegment(
      value: ThemeMode.light,
      label: Text('Light'),
      icon: Icon(Icons.light_mode_outlined),
    ),
    ButtonSegment(
      value: ThemeMode.dark,
      label: Text('Dark'),
      icon: Icon(Icons.dark_mode_outlined),
    ),
  ],
  selected: {themeMode},
  onSelectionChanged: (selection) {
    final selectedThemeMode = selection.single;
    // save selectedThemeMode
  },
)
```

`selected` принимает `Set`, потому что `SegmentedButton` умеет работать и в multi-select режиме. Мы используем один выбранный вариант, поэтому берем `selection.single`.

## Целевая структура после главы

```text
lib/
  src/
    app/
      app.dart
      router/
        app_router.dart
      theme/
        app_theme.dart
        theme_mode_controller.dart
    core/
      ui/
        app_breakpoints.dart
        app_radii.dart
        app_spacing.dart
    features/
      map/
        presentation/
          screens/
            map_screen.dart
          widgets/
            map_placeholder_panel.dart
      settings/
        presentation/
          screens/
            settings_screen.dart
          widgets/
            theme_mode_selector.dart
```

Можно сделать чуть меньше файлов, если код получается коротким. Но в этой главе полезно потренировать разделение:

- state темы - в `app/theme`;
- общие UI constants - в `core/ui`;
- reusable widgets конкретной feature - рядом с этой feature.

## Практика

### Шаг 1. Добавить `ThemeModeController`

Создай файл `lib/src/app/theme/theme_mode_controller.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode themeMode) {
    state = themeMode;
  }
}
```

Пока это in-memory state. После restart выбор сбросится на system. Это ожидаемо.

### Шаг 2. Подключить theme mode в `GeoMomentsApp`

В `lib/src/app/app.dart` добавь импорт:

```dart
import 'theme/theme_mode_controller.dart';
```

В `build` прочитай state:

```dart
final router = ref.watch(appRouterProvider);
final themeMode = ref.watch(themeModeControllerProvider);
```

И передай его в `MaterialApp.router`:

```dart
return MaterialApp.router(
  title: 'Geo Moments',
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode,
  routerConfig: router,
);
```

Теперь выбор темы может управляться извне.

### Шаг 3. Добавить design tokens

Создай `lib/src/core/ui/app_spacing.dart`:

```dart
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}
```

Создай `lib/src/core/ui/app_radius.dart`:

```dart
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
}
```

Создай `lib/src/core/ui/app_breakpoints.dart`:

```dart
abstract final class AppBreakpoints {
  static const tablet = 600.0;
  static const desktop = 1024.0;

  static bool isTabletWidth(double width) => width >= tablet;
}
```

Эти значения не финальные на всю жизнь. Мы просто задаем единый язык для UI.

### Шаг 4. Сделать selector темы

Создай файл `lib/src/features/settings/presentation/widgets/theme_mode_selector.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/theme_mode_controller.dart';

class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.brightness_auto_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {themeMode},
      onSelectionChanged: (selection) {
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(selection.single);
      },
    );
  }
}
```

Пока текст на английском. Локализацию будем делать в главе 3.

### Шаг 5. Обновить `SettingsScreen`

Сделай settings screen реальным экраном настроек:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../widgets/theme_mode_selector.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Theme'),
              SizedBox(height: AppSpacing.sm),
              ThemeModeSelector(),
            ],
          ),
        ),
      ),
    );
  }
}
```

Если analyzer ругается на `const` вокруг `ThemeModeSelector`, проверь, что у widget есть `const ThemeModeSelector({super.key});`.

### Шаг 6. Вынести map placeholder в widget

Создай файл `lib/src/features/map/presentation/widgets/map_placeholder_panel.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/app_radii.dart';

class MapPlaceholderPanel extends StatelessWidget {
  const MapPlaceholderPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text(
          'Map placeholder',
          style: textTheme.titleMedium,
        ),
      ),
    );
  }
}
```

Почему выносим:

- `MapScreen` будет отвечать за layout и navigation;
- placeholder widget отвечает только за внешний вид области карты;
- позже мы заменим этот widget на настоящий Mapbox widget или обернем карту в похожую оболочку.

### Шаг 7. Сделать responsive `MapScreen`

Идея:

- на телефоне показываем вертикальный layout;
- на планшете показываем карту и side panel рядом.

Пример целевого `MapScreen`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_router.dart';
import '../../../../core/ui/app_breakpoints.dart';
import '../../../../core/ui/app_spacing.dart';
import '../widgets/map_placeholder_panel.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet =
                AppBreakpoints.isTabletWidth(constraints.maxWidth);

            if (isTablet) {
              return const _TabletMapLayout();
            }

            return const _PhoneMapLayout();
          },
        ),
      ),
    );
  }
}

class _PhoneMapLayout extends StatelessWidget {
  const _PhoneMapLayout();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Expanded(child: MapPlaceholderPanel()),
          SizedBox(height: AppSpacing.md),
          _NearbyMomentsSummary(),
        ],
      ),
    );
  }
}

class _TabletMapLayout extends StatelessWidget {
  const _TabletMapLayout();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: MapPlaceholderPanel(),
          ),
          SizedBox(width: AppSpacing.lg),
          SizedBox(
            width: 320,
            child: _NearbyMomentsSummary(),
          ),
        ],
      ),
    );
  }
}

class _NearbyMomentsSummary extends StatelessWidget {
  const _NearbyMomentsSummary();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nearby moments', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Moments around you will appear here.',
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

Почему private widgets внутри файла начинаются с `_`:

- `_PhoneMapLayout` виден только в этом Dart-файле;
- это нормально для маленьких layout pieces;
- если widget станет переиспользуемым, вынесем его в отдельный файл.

### Шаг 8. Обновить тест

Текущий тест может остаться почти таким же, но теперь можно добавить проверку settings и selector-а.

Простой вариант:

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

  testWidgets('opens settings screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GeoMomentsApp(),
      ),
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });
}
```

Если у тебя tooltip сейчас `'settings'` с маленькой буквы, либо поменяй tooltip на `'Settings'`, либо ищи `find.byTooltip('settings')`. Лучше выбрать единый стиль с заглавной буквой, пока нет локализации.

## Проверка

Запустить:

```bash
flutter analyze
flutter test
```

Ручная проверка:

1. Открывается `Geo Moments`.
2. Кнопка Settings открывает настройки.
3. Системная Back-кнопка возвращает на карту.
4. В Settings есть выбор `System / Light / Dark`.
5. При выборе Dark приложение сразу становится темным.
6. При выборе Light приложение сразу становится светлым.
7. На узком экране layout вертикальный.
8. На широком экране layout становится двухпанельным.
9. В landscape ничего не обрезается и текст не налезает на соседние элементы.

## Частые ошибки

### Ошибка: тема меняется только на экране настроек

Причина: `ThemeMode` хранится локально в `SettingsScreen`, а не в provider, который читает `GeoMomentsApp`.

Решение: `MaterialApp.router` должен читать:

```dart
final themeMode = ref.watch(themeModeControllerProvider);
```

### Ошибка: `ConsumerWidget` не видит `ref`

Причина: класс все еще extends `StatelessWidget`.

Решение: экран или widget, который читает providers, должен быть `ConsumerWidget`, либо внутри можно использовать `Consumer`.

### Ошибка: Back из Settings закрывает приложение

Причина: Settings открыт через `context.go(...)`.

Решение:

```dart
context.push(AppRoutePaths.settings)
```

### Ошибка: `SegmentedButton` не обновляет выбранный вариант

Причина: в `selected` передано фиксированное значение, например `{ThemeMode.system}`, вместо state из provider.

Решение:

```dart
final themeMode = ref.watch(themeModeControllerProvider);
selected: {themeMode}
```

### Ошибка: layout ломается на планшете

Причина: фиксированные размеры заняли больше доступного места.

Решение: большие области оборачивать в `Expanded`, а фиксированную ширину использовать только для side panel, где она действительно нужна.

## Definition of Done

- `ThemeModeController` создан и подключен к `GeoMomentsApp`.
- Settings screen позволяет выбрать System, Light, Dark.
- Тема меняется сразу без перезапуска приложения.
- Добавлены `AppSpacing`, `AppRadius`, `AppBreakpoints`.
- `MapScreen` использует responsive layout через `LayoutBuilder`.
- На телефоне layout вертикальный.
- На планшетной ширине layout двухпанельный.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка portrait/landscape выполнена.

## Что я буду проверять в ревью

- Не хранится ли theme state внутри widget state.
- Не появился ли hardcoded `ThemeMode.system` в `MaterialApp`.
- Не размазаны ли отступы и радиусы случайными числами по экрану.
- Не сломан ли Back из Settings.
- Не стал ли `MapScreen` слишком большим без нужды.
- Не используются ли `MediaQuery` и fixed sizes там, где лучше constraints.

Когда закончишь, напиши:

```text
Глава 2 готова, проверь код.
```

