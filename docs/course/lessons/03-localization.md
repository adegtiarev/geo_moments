# 03 Localization

Статус: next.

## Что строим в этой главе

Добавляем в Geo Moments полноценную локализацию интерфейса:

- английский;
- русский;
- испанский;
- ручное переключение языка в настройках;
- системный режим языка;
- генерация typed localization API через Flutter `gen-l10n`;
- замена hardcoded строк в текущем UI.

После главы пользователь сможет зайти в Settings и переключить язык приложения без перезапуска.

## Почему это важно

Локализация - это не просто "словарик строк". В реальном приложении она влияет на:

- навигационные title;
- кнопки и tooltips;
- empty states;
- plural forms;
- даты, числа, валюты;
- screenshots для App Store / Google Play;
- тесты UI.

Если строки оставить hardcoded, через несколько глав мы получим много ручной работы: придется искать тексты по всему проекту, переносить их в ресурсы и чинить тесты. Лучше заложить i18n сейчас, пока UI небольшой.

В Android legacy аналогом были `strings.xml` в `res/values`, `res/values-ru`, `res/values-es`. Во Flutter официальная схема похожа по идее, но файлы называются `.arb`, а typed Dart API генерируется командой `gen-l10n`.

## Словарь главы

`i18n` - internationalization, подготовка приложения к разным языкам и регионам.

`l10n` - localization, конкретные переводы для конкретных языков.

`Locale` - язык/регион, например `Locale('en')`, `Locale('ru')`, `Locale('es')`.

`ARB` - Application Resource Bundle, JSON-подобный формат для локализованных сообщений.

`gen-l10n` - Flutter tool, который генерирует Dart-класс `AppLocalizations` из ARB-файлов.

`localizationsDelegates` - список delegates, которые загружают локализации для Material, Cupertino, Widgets и нашего приложения.

`supportedLocales` - список локалей, которые приложение поддерживает.

`locale` в `MaterialApp` - принудительно выбранная локаль. Если `null`, Flutter использует системную.

## 1. Как локализация работает во Flutter

В упрощенном виде поток такой:

```text
app_en.arb / app_ru.arb / app_es.arb
  -> flutter gen-l10n
  -> generated AppLocalizations class
  -> MaterialApp подключает delegates и supportedLocales
  -> widgets читают строки через context.l10n.someKey
```

В коде вместо:

```dart
Text('Settings')
```

будет:

```dart
Text(context.l10n.settingsTitle)
```

Это дает:

- compile-time проверку ключей;
- автодополнение в IDE;
- меньше опечаток;
- понятную ошибку, если перевод не добавлен.

## 2. Почему не используем `package:flutter_gen`

Раньше во Flutter часто импортировали generated localizations так:

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

В актуальном Flutter это уже не лучший путь. Flutter перешел к генерации localization source прямо в `lib/`, а `package:flutter_gen` как synthetic package уходит из рекомендуемого подхода.

Поэтому в этом проекте используем:

```yaml
output-dir: lib/src/generated/l10n
```

И импорт:

```dart
import 'package:geo_moments/src/generated/l10n/app_localizations.dart';
```

Это надежнее для IDE, CI и GitHub.

Во Flutter 3.41 опция `synthetic-package` уже не нужна. Если добавить ее в `l10n.yaml`, `flutter gen-l10n` покажет warning:

```text
The argument "synthetic-package" no longer has any effect and should be removed.
```

Это не ошибка генерации, но опцию нужно удалить, чтобы конфиг был актуальным.

## 3. Что добавляет `flutter_localizations`

Наши строки - это только часть локализации. Flutter Material widgets тоже имеют встроенные тексты:

- back button tooltip;
- date picker;
- time picker;
- modal barrier labels;
- text field selection menu;
- Cupertino controls.

Чтобы они тоже переводились, нужен SDK package:

```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

`flutter_localizations` дает delegates для Flutter widgets. `intl` нужен для форматирования сообщений, plural/select, дат и чисел.

## 4. Что такое ARB

ARB - это JSON-файл с ключами сообщений.

Пример `app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "Geo Moments",
  "@appTitle": {
    "description": "Application title"
  },
  "settingsTitle": "Settings",
  "@settingsTitle": {
    "description": "Settings screen title"
  }
}
```

Обычный ключ:

```json
"settingsTitle": "Settings"
```

Метаданные:

```json
"@settingsTitle": {
  "description": "Settings screen title"
}
```

Метаданные нужны для переводчиков и для будущей поддержки команды. Мы будем писать description для новых ключей.

Русский файл будет иметь те же ключи:

```json
{
  "@@locale": "ru",
  "appTitle": "Geo Moments",
  "settingsTitle": "Настройки"
}
```

Испанский:

```json
{
  "@@locale": "es",
  "appTitle": "Geo Moments",
  "settingsTitle": "Configuración"
}
```

Ключи должны совпадать во всех языках.

## 5. Как подключить локализацию к `MaterialApp.router`

Сейчас `GeoMomentsApp` примерно такой:

```dart
return MaterialApp.router(
  title: 'Geo Moments',
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode,
  routerConfig: router,
);
```

После главы добавим:

```dart
return MaterialApp.router(
  onGenerateTitle: (context) => context.l10n.appTitle,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: localePreference.locale,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode,
  routerConfig: router,
);
```

Почему `onGenerateTitle`, а не `title`:

- `title` - обычная строка, она не зависит от `BuildContext`;
- `onGenerateTitle` вызывается после инициализации localizations;
- значит, title тоже может быть переведен.

## 6. Системный язык и ручной выбор

Если передать в `MaterialApp`:

```dart
locale: null
```

Flutter выберет язык из системы, если он есть в `supportedLocales`.

Если передать:

```dart
locale: const Locale('ru')
```

приложение будет на русском независимо от системного языка.

Нам нужно четыре варианта:

- System;
- English;
- Русский;
- Español.

Для этого удобно создать enum:

```dart
enum LocalePreference {
  system,
  english,
  russian,
  spanish;

  Locale? get locale {
    return switch (this) {
      LocalePreference.system => null,
      LocalePreference.english => const Locale('en'),
      LocalePreference.russian => const Locale('ru'),
      LocalePreference.spanish => const Locale('es'),
    };
  }
}
```

`system` возвращает `null`, потому что именно `null` означает "пусть Flutter выберет системную локаль".

## 7. Riverpod controller для языка

Похоже на `ThemeModeController`:

```dart
final localeControllerProvider =
    NotifierProvider<LocaleController, LocalePreference>(
  LocaleController.new,
);

class LocaleController extends Notifier<LocalePreference> {
  @override
  LocalePreference build() => LocalePreference.system;

  void setLocalePreference(LocalePreference preference) {
    state = preference;
  }
}
```

Пока state in-memory. После перезапуска приложения выбранный язык сбросится на system. Persist settings добавим позже, когда будем вводить локальное хранение настроек.

## 8. Удобный `context.l10n`

Можно каждый раз писать:

```dart
AppLocalizations.of(context).settingsTitle
```

Но это шумно. Создадим extension:

```dart
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

Тогда в UI:

```dart
Text(context.l10n.settingsTitle)
```

Это коротко, читаемо и хорошо масштабируется.

## 9. Что делать с user content

Мы локализуем **UI**, но не локализуем пользовательский контент.

Если пользователь написал момент:

```text
Тут был лучший кофе
```

то он так и хранится. Мы не переводим его автоматически. В будущем можно добавить machine translation, но это отдельная продуктовая задача и она не нужна для MVP.

## Целевая структура после главы

```text
lib/
  l10n/
    app_en.arb
    app_ru.arb
    app_es.arb
    untranslated_messages.txt       generated/check artifact
  src/
    app/
      app.dart
      localization/
        app_localizations_context.dart
        locale_controller.dart
    generated/
      l10n/
        app_localizations.dart       generated
        app_localizations_en.dart    generated
        app_localizations_ru.dart    generated
        app_localizations_es.dart    generated
    features/
      settings/
        presentation/
          widgets/
            locale_selector.dart
l10n.yaml
```

Generated files в `lib/src/generated/l10n` можно коммитить. Это делает сборку и IDE поведение стабильнее.

## Практика

### Шаг 1. Добавить зависимости

```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

В `pubspec.yaml` должно появиться:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
```

В секции `flutter` добавь:

```yaml
flutter:
  generate: true
  uses-material-design: true
```

`generate: true` обязателен для generated l10n source.

### Шаг 2. Создать `l10n.yaml`

В корне проекта:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-dir: lib/src/generated/l10n
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
untranslated-messages-file: lib/l10n/untranslated_messages.txt
```

Разбор:

- `arb-dir` - где лежат ARB-файлы;
- `template-arb-file` - главный файл, источник ключей;
- `output-dir` - куда генерировать Dart-код; этот параметр заменяет старый synthetic package подход;
- `nullable-getter: false` - `AppLocalizations.of(context)` будет non-nullable;
- `untranslated-messages-file` - файл с пропущенными переводами.

### Шаг 3. Создать ARB-файлы

Создай `lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "Geo Moments",
  "@appTitle": {
    "description": "Application title"
  },
  "mapTitle": "Geo Moments",
  "@mapTitle": {
    "description": "Main map screen app bar title"
  },
  "settingsTitle": "Settings",
  "@settingsTitle": {
    "description": "Settings screen title"
  },
  "settingsTooltip": "Settings",
  "@settingsTooltip": {
    "description": "Tooltip for the settings button"
  },
  "mapPlaceholder": "Map placeholder",
  "@mapPlaceholder": {
    "description": "Temporary placeholder text for the future map"
  },
  "nearbyMomentsTitle": "Nearby moments",
  "@nearbyMomentsTitle": {
    "description": "Title for the nearby moments summary panel"
  },
  "nearbyMomentsEmpty": "Moments around you will appear here.",
  "@nearbyMomentsEmpty": {
    "description": "Empty state text for nearby moments"
  },
  "themeSettingTitle": "Theme",
  "@themeSettingTitle": {
    "description": "Settings row title for theme selection"
  },
  "themeSystem": "System",
  "@themeSystem": {
    "description": "System theme mode option"
  },
  "themeLight": "Light",
  "@themeLight": {
    "description": "Light theme mode option"
  },
  "themeDark": "Dark",
  "@themeDark": {
    "description": "Dark theme mode option"
  },
  "languageSettingTitle": "Language",
  "@languageSettingTitle": {
    "description": "Settings row title for language selection"
  },
  "languageSystem": "System",
  "@languageSystem": {
    "description": "System language option"
  },
  "languageEnglish": "English",
  "@languageEnglish": {
    "description": "English language option"
  },
  "languageRussian": "Russian",
  "@languageRussian": {
    "description": "Russian language option"
  },
  "languageSpanish": "Spanish",
  "@languageSpanish": {
    "description": "Spanish language option"
  }
}
```

Создай `lib/l10n/app_ru.arb`:

```json
{
  "@@locale": "ru",
  "appTitle": "Geo Moments",
  "mapTitle": "Geo Moments",
  "settingsTitle": "Настройки",
  "settingsTooltip": "Настройки",
  "mapPlaceholder": "Здесь будет карта",
  "nearbyMomentsTitle": "Моменты рядом",
  "nearbyMomentsEmpty": "Здесь появятся моменты рядом с вами.",
  "themeSettingTitle": "Тема",
  "themeSystem": "Системная",
  "themeLight": "Светлая",
  "themeDark": "Темная",
  "languageSettingTitle": "Язык",
  "languageSystem": "Системный",
  "languageEnglish": "Английский",
  "languageRussian": "Русский",
  "languageSpanish": "Испанский"
}
```

Создай `lib/l10n/app_es.arb`:

```json
{
  "@@locale": "es",
  "appTitle": "Geo Moments",
  "mapTitle": "Geo Moments",
  "settingsTitle": "Configuración",
  "settingsTooltip": "Configuración",
  "mapPlaceholder": "Aquí estará el mapa",
  "nearbyMomentsTitle": "Momentos cercanos",
  "nearbyMomentsEmpty": "Aquí aparecerán los momentos cercanos.",
  "themeSettingTitle": "Tema",
  "themeSystem": "Sistema",
  "themeLight": "Claro",
  "themeDark": "Oscuro",
  "languageSettingTitle": "Idioma",
  "languageSystem": "Sistema",
  "languageEnglish": "Inglés",
  "languageRussian": "Ruso",
  "languageSpanish": "Español"
}
```

На практике переводы можно будет улучшать. Сейчас важно правильно подключить механизм.

### Шаг 4. Сгенерировать локализации

```bash
flutter gen-l10n
```

После этого должны появиться generated files:

```text
lib/src/generated/l10n/app_localizations.dart
lib/src/generated/l10n/app_localizations_en.dart
lib/src/generated/l10n/app_localizations_ru.dart
lib/src/generated/l10n/app_localizations_es.dart
```

Если Android Studio не видит generated imports, сделай:

```bash
flutter pub get
```

и перезапусти Dart Analysis Server.

### Шаг 5. Добавить `context.l10n`

Создай `lib/src/app/localization/app_localizations_context.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../generated/l10n/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

Теперь любые widgets могут читать строки так:

```dart
context.l10n.settingsTitle
```

### Шаг 6. Добавить locale controller

Создай `lib/src/app/localization/locale_controller.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider =
    NotifierProvider<LocaleController, LocalePreference>(
  LocaleController.new,
);

enum LocalePreference {
  system,
  english,
  russian,
  spanish;

  Locale? get locale {
    return switch (this) {
      LocalePreference.system => null,
      LocalePreference.english => const Locale('en'),
      LocalePreference.russian => const Locale('ru'),
      LocalePreference.spanish => const Locale('es'),
    };
  }
}

class LocaleController extends Notifier<LocalePreference> {
  @override
  LocalePreference build() => LocalePreference.system;

  void setLocalePreference(LocalePreference preference) {
    state = preference;
  }
}
```

Почему state - enum, а не `Locale?`:

- enum удобнее показывать в selector;
- `system` явно выражает пользовательский выбор;
- `Locale?` нужен только на границе с `MaterialApp`.

### Шаг 7. Подключить локализацию в `GeoMomentsApp`

В `lib/src/app/app.dart` добавь imports:

```dart
import 'localization/app_localizations_context.dart';
import 'localization/locale_controller.dart';
import '../generated/l10n/app_localizations.dart';
```

В `build`:

```dart
final localePreference = ref.watch(localeControllerProvider);
```

В `MaterialApp.router`:

```dart
return MaterialApp.router(
  onGenerateTitle: (context) => context.l10n.appTitle,
  debugShowCheckedModeBanner: false,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: localePreference.locale,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode,
  routerConfig: router,
);
```

`title: 'Geo Moments'` можно убрать, потому что теперь есть `onGenerateTitle`.

### Шаг 8. Локализовать текущие widgets

В `MapScreen`:

```dart
import '../../../../app/localization/app_localizations_context.dart';
```

Заменить:

```dart
title: const Text('Geo Moments')
tooltip: 'Settings'
```

на:

```dart
title: Text(context.l10n.mapTitle)
tooltip: context.l10n.settingsTooltip
```

В `_NearbyMomentsSummary` заменить:

```dart
Text('Nearby moments', ...)
Text('Moments around you will appear here.', ...)
```

на:

```dart
Text(context.l10n.nearbyMomentsTitle, ...)
Text(context.l10n.nearbyMomentsEmpty, ...)
```

В `MapPlaceholderPanel`:

```dart
import '../../../../app/localization/app_localizations_context.dart';
```

Заменить:

```dart
Text('Map placeholder', style: textTheme.titleMedium)
```

на:

```dart
Text(context.l10n.mapPlaceholder, style: textTheme.titleMedium)
```

В `SettingsScreen` заменить:

```dart
title: const Text('Settings')
Text('Theme')
```

на:

```dart
title: Text(context.l10n.settingsTitle)
Text(context.l10n.themeSettingTitle)
```

### Шаг 9. Локализовать `ThemeModeSelector`

Добавь:

```dart
import '../../../../app/localization/app_localizations_context.dart';
```

Заменить labels:

```dart
label: Text(context.l10n.themeSystem)
label: Text(context.l10n.themeLight)
label: Text(context.l10n.themeDark)
```

Из-за `context.l10n` список `segments` уже не может быть `const`.

Было:

```dart
segments: const [
```

Станет:

```dart
segments: [
```

Это нормально: локализованные строки зависят от runtime context.

### Шаг 10. Добавить selector языка

Создай `lib/src/features/settings/presentation/widgets/locale_selector.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../app/localization/locale_controller.dart';

class LocaleSelector extends ConsumerWidget {
  const LocaleSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localePreference = ref.watch(localeControllerProvider);

    return SegmentedButton<LocalePreference>(
      segments: [
        ButtonSegment(
          value: LocalePreference.system,
          label: Text(context.l10n.languageSystem),
          icon: const Icon(Icons.language_outlined),
        ),
        ButtonSegment(
          value: LocalePreference.english,
          label: Text(context.l10n.languageEnglish),
        ),
        ButtonSegment(
          value: LocalePreference.russian,
          label: Text(context.l10n.languageRussian),
        ),
        ButtonSegment(
          value: LocalePreference.spanish,
          label: Text(context.l10n.languageSpanish),
        ),
      ],
      selected: {localePreference},
      onSelectionChanged: (selection) {
        ref
            .read(localeControllerProvider.notifier)
            .setLocalePreference(selection.single);
      },
    );
  }
}
```

Да, на телефоне четыре segment-а могут быть тесными. Если UI получится слишком широким, замени `SegmentedButton` на `DropdownMenu<LocalePreference>`. Это нормальное инженерное решение: `SegmentedButton` хорош для 2-3 коротких вариантов, а язык часто лучше выглядит как dropdown.

Для этой главы я бы сначала попробовал `SegmentedButton`, чтобы закрепить паттерн, а если на эмуляторе текст не помещается - перейти на `DropdownMenu`.

### Шаг 11. Добавить language section в `SettingsScreen`

Добавь import:

```dart
import '../widgets/locale_selector.dart';
import '../../../../app/localization/app_localizations_context.dart';
```

В `Column`:

```dart
Text(context.l10n.themeSettingTitle),
const SizedBox(height: AppSpacing.sm),
const ThemeModeSelector(),
const SizedBox(height: AppSpacing.lg),
Text(context.l10n.languageSettingTitle),
const SizedBox(height: AppSpacing.sm),
const LocaleSelector(),
```

Так как тексты теперь runtime, `body: const SafeArea(...)` больше не будет полностью `const`.

## Шаг 12. Обновить tests

Тесты теперь должны учитывать локализацию.

Минимальный test все еще может искать English default:

```dart
expect(find.text('Geo Moments'), findsOneWidget);
expect(find.text('Map placeholder'), findsOneWidget);
```

Добавь тест переключения языка:

```dart
testWidgets('switches app language to Russian', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: GeoMomentsApp(),
    ),
  );

  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Russian'));
  await tester.pumpAndSettle();

  expect(find.text('Настройки'), findsOneWidget);
  expect(find.text('Тема'), findsOneWidget);
  expect(find.text('Язык'), findsOneWidget);
});
```

Если сделаешь `DropdownMenu`, тест будет другим: нужно открыть dropdown и выбрать item.

## Проверка

Запустить:

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

Ручная проверка:

1. Приложение стартует на системном языке, если он `en`, `ru` или `es`.
2. Settings открывается.
3. Можно выбрать English.
4. Можно выбрать Русский.
5. Можно выбрать Español.
6. AppBar title, settings labels, theme labels, language labels меняются сразу.
7. Back из Settings возвращает на карту.
8. После перезапуска приложения язык снова system. Это ожидаемо в этой главе.

## Частые ошибки

### Ошибка: `Target of URI doesn't exist: app_localizations.dart`

Причина: generated files еще не созданы.

Решение:

```bash
flutter gen-l10n
```

Если не помогло:

```bash
flutter pub get
```

и перезапустить Dart Analysis Server.

### Ошибка: импорт через `package:flutter_gen`

Причина: старый подход из старых гайдов.

Решение: в этом проекте импортируем generated source из:

```dart
import 'package:geo_moments/src/generated/l10n/app_localizations.dart';
```

### Ошибка: `AppLocalizations.of(context)` возвращает nullable

Причина: в `l10n.yaml` нет:

```yaml
nullable-getter: false
```

Можно жить и с nullable вариантом, но в этом проекте используем non-nullable getter.

### Ошибка: `const` больше не работает

Причина: локализованные строки приходят из `context` во время runtime.

Было:

```dart
const Text('Settings')
```

Стало:

```dart
Text(context.l10n.settingsTitle)
```

Это уже не `const`, и это нормально.

### Ошибка: длинные русские/испанские строки не помещаются

Причина: UI был рассчитан только на английский.

Решение:

- разрешить перенос текста;
- использовать `DropdownMenu` вместо `SegmentedButton`;
- проверять UI на всех поддерживаемых языках.

Это одна из причин, почему локализацию вводим рано.

### Ошибка: preview widget падает из-за `context.l10n`

Причина: preview widget не обернут в `MaterialApp` с localizationsDelegates.

Решение: для previews, которые используют локализацию, нужен wrapper с `MaterialApp`:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ...
)
```

## Definition of Done

- Добавлены `flutter_localizations` и `intl`.
- В `pubspec.yaml` есть `flutter: generate: true`.
- Создан `l10n.yaml` с `output-dir: lib/src/generated/l10n`.
- Созданы `app_en.arb`, `app_ru.arb`, `app_es.arb`.
- Generated localizations лежат в `lib/src/generated/l10n`.
- `GeoMomentsApp` подключает delegates, supportedLocales и locale.
- Добавлен `LocaleController`.
- Settings screen позволяет выбрать System, English, Russian, Spanish.
- Hardcoded UI strings из текущих экранов заменены на localizations.
- `flutter analyze` проходит.
- `flutter test` проходит.
- Ручная проверка переключения языков выполнена.

## Что я буду проверять в ревью

- Нет ли новых hardcoded UI strings в текущих widgets.
- Не используется ли старый `package:flutter_gen`.
- Не забыты ли generated files.
- Не сломан ли `ThemeModeSelector` после добавления локализованных labels.
- Не ломается ли layout на русском и испанском.
- Не хранится ли locale state локально внутри `SettingsScreen`.

Когда закончишь, напиши:

```text
Глава 3 готова, проверь код.
```
