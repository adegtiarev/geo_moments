# 04 Supabase Project and Environment Config

Статус: next.

## Что строим в этой главе

В этой главе мы впервые подключаем backend, но пока не делаем авторизацию, таблицы моментов или storage upload.

Цель главы - безопасно и правильно подготовить инфраструктурный слой:

- создать Supabase project в dashboard;
- добавить Flutter packages для Supabase и `.env`;
- не коммитить реальные ключи;
- загрузить runtime config до старта приложения;
- инициализировать `Supabase`;
- создать typed `AppConfig`;
- добавить маленький health-check в Settings, чтобы видеть, что клиент создан и конфиг подхвачен.

После главы приложение по-прежнему будет работать без реальных данных. Но у него появится backend foundation.

## Почему это важно

Backend SDK нельзя подключать "по месту" в первом попавшемся widget. Если экран сам читает URL, ключи и создает клиент, дальше появятся проблемы:

- auth state будет размазан по UI;
- тесты станут зависеть от реального Supabase;
- сложнее разделить dev/prod окружения;
- легко случайно закоммитить секреты;
- сложно диагностировать ошибку конфигурации на старте.

Поэтому подключаем Supabase на уровне bootstrap до `runApp`, а в UI показываем только безопасное состояние.

В Android/Spring терминах это похоже на:

- `application.yml` / environment variables;
- typed config properties;
- app startup initialization;
- dependency, доступная приложению после bootstrap.

## Словарь главы

`Supabase` - backend platform: Postgres, Auth, Storage, Realtime, Edge Functions.

`supabase_flutter` - Flutter SDK, который инициализирует Supabase client и auth storage.

`anon key` - public API key для клиентского приложения. Это не service role secret, но его все равно лучше держать в env/config, а не размазывать по коду.

`service role key` - секретный серверный ключ. Никогда не кладем в mobile app.

`.env` - локальный файл окружения для разработки. Не коммитим.

`.env.example` - шаблон переменных без реальных значений. Коммитим.

`bootstrap` - стартовая подготовка приложения до `runApp`.

`health-check` - простая проверка, что конфигурация загружена и SDK инициализирован.

## 1. Какие ключи Supabase бывают

В Supabase dashboard ты увидишь разные ключи.

Для Flutter app нужен:

- Project URL;
- anon public key.

Нельзя использовать в мобильном приложении:

- service role key.

Почему: mobile app можно декомпилировать. Все, что попало в APK/IPA, нельзя считать секретом. `anon key` рассчитан на клиентское использование вместе с Row Level Security. `service role key` обходит RLS и должен жить только на backend/Edge Functions/CI secrets.

В этой главе мы используем только:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

## 2. Почему `.env` не является настоящей защитой секрета

Важно понимать: `.env` в mobile app - это не "секретное хранилище".

На этапе сборки значения попадут в приложение. Значит, злоумышленник может их извлечь. Поэтому безопасность Supabase строится не на скрытии anon key, а на:

- RLS policies;
- ограниченных grants;
- правильной схеме таблиц;
- серверной логике там, где клиенту нельзя доверять.

Тогда зачем `.env`?

- не хардкодить значения в Dart-коде;
- легко менять dev/staging/prod;
- не коммитить личные project credentials;
- сделать onboarding через `.env.example`.

## 3. Что такое app bootstrap

Сейчас `main.dart` примерно такой:

```dart
void main() {
  runApp(const ProviderScope(child: GeoMomentsApp()));
}
```

После главы будет:

```dart
Future<void> main() async {
  await bootstrap();
}
```

А `bootstrap` сделает:

```dart
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
      ],
      child: const GeoMomentsApp(),
    ),
  );
}
```

Почему нужен `WidgetsFlutterBinding.ensureInitialized()`:

- до `runApp` мы вызываем plugin/platform code;
- Flutter должен подготовить binding;
- многие SDK требуют это перед async initialization.

## 4. Почему config лучше сделать typed

Плохой вариант:

```dart
final url = dotenv.env['SUPABASE_URL']!;
final key = dotenv.env['SUPABASE_ANON_KEY']!;
```

Если так писать в разных местах, ошибки будут повторяться.

Лучше:

```dart
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;
}
```

И один метод загрузки:

```dart
static Future<AppConfig> load() async { ... }
```

Тогда приложение получает уже валидированный config.

## 5. Как валидировать config

Минимально проверяем:

- переменная есть;
- переменная не пустая;
- URL действительно URL.

Пример:

```dart
final supabaseUri = Uri.tryParse(supabaseUrl);
if (supabaseUri == null || !supabaseUri.hasScheme || !supabaseUri.hasAuthority) {
  throw StateError('SUPABASE_URL must be a valid URL.');
}
```

Это не заменяет интеграционный тест, но помогает сразу поймать очевидную ошибку.

## 6. Как дать config в Riverpod

Config нужен редко, но полезно иметь его в provider:

```dart
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in bootstrap.');
});
```

Почему provider бросает ошибку:

- config должен приходить только из bootstrap;
- если забыли override, приложение упадет явно;
- тесты смогут подставить fake config.

В bootstrap:

```dart
ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(config),
  ],
  child: const GeoMomentsApp(),
)
```

## 7. Как получить Supabase client

После:

```dart
await Supabase.initialize(...)
```

client доступен так:

```dart
final client = Supabase.instance.client;
```

Но не стоит дергать `Supabase.instance.client` напрямую из каждого widget. Лучше сделать provider:

```dart
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

В будущих repositories мы будем получать client через provider/constructor, а не напрямую в UI.

## 8. Что такое health-check в этой главе

Мы еще не создаем таблицы. Поэтому health-check будет очень простым:

- config загружен;
- Supabase client инициализирован;
- URL выглядит валидно.

В Settings можно показать:

```text
Backend
Supabase configured
```

Это не проверяет доступ к базе. Настоящую проверку с SQL/таблицами сделаем в главе 6.

## 9. Что добавить в `.gitignore`

Нужно убедиться, что `.env` игнорируется.

Коммитим:

```text
.env.example
```

Не коммитим:

```text
.env
```

Если `.env` уже попал в Git, его нужно удалить из индекса:

```bash
git rm --cached .env
```

Но не удаляй сам локальный файл с диска, если он нужен для запуска.

## Целевая структура после главы

```text
.env.example
.env                         local only, ignored
lib/
  main.dart
  src/
    app/
      bootstrap/
        bootstrap.dart
      config/
        app_config.dart
      app.dart
    core/
      backend/
        supabase_client_provider.dart
    features/
      settings/
        presentation/
          widgets/
            backend_status_tile.dart
```

## Практика

### Шаг 1. Создать Supabase project

В Supabase dashboard создай новый project.

Для курса достаточно:

- Region: ближайший к тебе или пользователям;
- Database password: сохрани в password manager;
- Project name: `geo-moments-dev` или похожее.

После создания найди:

- Project URL;
- anon public key.

Не бери service role key.

### Шаг 2. Добавить dependencies

```bash
flutter pub add supabase_flutter flutter_dotenv
```

Ожидаемо в `pubspec.yaml`:

```yaml
dependencies:
  supabase_flutter: ^...
  flutter_dotenv: ^...
```

Версии могут отличаться.

### Шаг 3. Добавить `.env.example`

В корне проекта:

```text
SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

Это шаблон. Реальные значения сюда не вставлять.

### Шаг 4. Добавить локальный `.env`

В корне проекта создай `.env` с реальными значениями:

```text
SUPABASE_URL=https://actual-project-id.supabase.co
SUPABASE_ANON_KEY=actual-anon-key
```

Проверь `.gitignore`:

```text
.env
```

Если `.gitignore` не содержит `.env`, добавь.

### Шаг 5. Подключить `.env` как asset

В `pubspec.yaml`:

```yaml
flutter:
  generate: true
  uses-material-design: true
  assets:
    - .env
```

Почему `.env` asset: `flutter_dotenv` читает файл из assets bundle.

Для production позже обсудим flavors и `--dart-define`. Сейчас `.env` проще для курса.

### Шаг 6. Создать `AppConfig`

Файл `lib/src/app/config/app_config.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError('appConfigProvider must be overridden in bootstrap.');
});

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final String supabaseUrl;
  final String supabaseAnonKey;

  static Future<AppConfig> load() async {
    await dotenv.load();

    final supabaseUrl = _requiredEnv('SUPABASE_URL');
    final supabaseAnonKey = _requiredEnv('SUPABASE_ANON_KEY');

    _validateUrl(supabaseUrl);

    return AppConfig(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  static String _requiredEnv(String key) {
    final value = dotenv.env[key];

    if (value == null || value.trim().isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }

    return value.trim();
  }

  static void _validateUrl(String value) {
    final uri = Uri.tryParse(value);

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw StateError('SUPABASE_URL must be a valid URL.');
    }
  }
}
```

### Шаг 7. Создать Supabase provider

Файл `lib/src/core/backend/supabase_client_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

Пока он не используется для запросов. В следующих главах через него пойдут repositories.

### Шаг 8. Создать bootstrap

Файл `lib/src/app/bootstrap/bootstrap.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../config/app_config.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await AppConfig.load();

  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
      ],
      child: const GeoMomentsApp(),
    ),
  );
}
```

### Шаг 9. Обновить `main.dart`

```dart
import 'src/app/bootstrap/bootstrap.dart';

Future<void> main() async {
  await bootstrap();
}
```

Теперь `main.dart` снова маленький, но уже async.

### Шаг 10. Добавить backend status tile

Файл `lib/src/features/settings/presentation/widgets/backend_status_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';

class BackendStatusTile extends ConsumerWidget {
  const BackendStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final host = Uri.parse(config.supabaseUrl).host;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cloud_done_outlined),
      title: const Text('Backend'),
      subtitle: Text('Supabase configured: $host'),
    );
  }
}
```

Тут пока можно оставить английский текст, но лучше добавить строки в ARB:

```json
"backendSettingTitle": "Backend",
"backendConfigured": "Supabase configured: {host}"
```

Если хочешь закрепить локализацию, добавь эти ключи сразу для EN/RU/ES.

### Шаг 11. Добавить tile в Settings

В `SettingsScreen` после language selector:

```dart
const SizedBox(height: AppSpacing.lg),
const BackendStatusTile(),
```

Не забудь import.

### Шаг 12. Обновить tests

После bootstrap `main.dart` грузит `.env`, но widget tests обычно продолжают pump-ить `GeoMomentsApp` напрямую. Значит, в тестах нужно override-нуть `appConfigProvider`.

Пример helper:

```dart
const testAppConfig = AppConfig(
  supabaseUrl: 'https://test.supabase.co',
  supabaseAnonKey: 'test-anon-key',
);

Widget buildTestApp() {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(testAppConfig),
    ],
    child: const GeoMomentsApp(),
  );
}
```

И в тестах:

```dart
await tester.pumpWidget(buildTestApp());
```

Почему так: widget tests не должны зависеть от локального `.env` и реального Supabase project.

## Проверка

Запустить:

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter run
```

Ручная проверка:

1. Приложение стартует без ошибок.
2. Settings открывается.
3. Theme selector работает.
4. Language selector работает.
5. В Settings виден backend status.
6. В backend status отображается host Supabase project.
7. `.env` не отображается в `git status`.
8. `.env.example` отображается и должен быть закоммичен.

## Частые ошибки

### Ошибка: `.env` not found

Причины:

- файл `.env` не создан;
- `.env` не добавлен в `flutter.assets`;
- после изменения `pubspec.yaml` не был перезапущен app.

Решение:

```bash
flutter pub get
flutter run
```

И проверить:

```yaml
flutter:
  assets:
    - .env
```

### Ошибка: `appConfigProvider must be overridden`

Причина: `GeoMomentsApp` запущен без bootstrap и без test override.

В приложении запускаем через `main.dart -> bootstrap`.

В тестах:

```dart
ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(testAppConfig),
  ],
  child: const GeoMomentsApp(),
)
```

### Ошибка: случайно закоммитил `.env`

Если `.env` уже tracked:

```bash
git rm --cached .env
```

Потом убедиться:

```bash
git status --short
```

В status не должно быть `.env`.

### Ошибка: использовал service role key

Нельзя. Удали ключ из `.env`, сгенерируй новый service role key в Supabase dashboard, если он мог попасть в Git или чужие руки.

В mobile app должен быть только anon public key.

### Ошибка: тесты требуют настоящий `.env`

Это неправильная зависимость. Widget tests должны использовать fake/test config через provider override.

## Definition of Done

- Supabase project создан.
- `supabase_flutter` и `flutter_dotenv` добавлены.
- `.env.example` создан и закоммичен.
- `.env` создан локально и игнорируется Git.
- `AppConfig` загружает и валидирует env.
- `bootstrap()` инициализирует Supabase до `runApp`.
- `main.dart` вызывает `bootstrap`.
- `supabaseClientProvider` создан.
- Settings показывает backend status.
- Тесты используют `appConfigProvider.overrideWithValue`.
- `flutter analyze` проходит.
- `flutter test` проходит.
- `flutter run` стартует приложение с реальным `.env`.

## Что я буду проверять в ревью

- Не попал ли `.env` или реальные ключи в Git.
- Не используется ли service role key.
- Не читает ли UI `.env` напрямую.
- Не создается ли Supabase client внутри widgets.
- Не завязаны ли tests на реальный Supabase project.
- Bootstrap остается маленьким и понятным.

Когда закончишь, напиши:

```text
Глава 4 готова, проверь код.
```

