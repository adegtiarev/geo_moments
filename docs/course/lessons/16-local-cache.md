# 16 Local Cache

Статус: draft.

## Что строим

В главе 15 Geo Moments получил нормальный adaptive UI: телефон сохраняет bottom sheet preview, а tablet и landscape используют side panel. В главе 16 добавим локальный кэш последних moments.

После главы приложение должно уметь:

- сохранять последние загруженные nearby moments в SQLite;
- показывать cached moments при старте или слабой сети;
- обновлять экран из Supabase, когда сеть снова доступна;
- сохранять созданный moment в кэш после успешной публикации;
- не ломать details, likes, comments, push notification routing и wide layout из прошлых глав.

Это не offline-first в полном смысле. Мы не будем создавать moments offline, синхронизировать очереди upload-ов или решать conflicts. Цель главы уже: сделать read-side надежнее и объяснить границу локального кэша.

## Почему это важно

Сейчас `nearbyMomentsProvider` зависит от Supabase. Если приложение открыто в метро, на слабом Wi-Fi или сразу после cold start без сети, пользователь видит retry UI. Это честное поведение, но для портфолио-MVP лучше показать последние известные moments и параллельно попытаться обновить их.

В Android-опыте это похоже на Room + Repository:

```text
UI
  -> watches repository state
Repository
  -> reads Room first
  -> asks network
  -> writes Room
  -> UI receives fresh data
```

Во Flutter мы сделаем ту же идею через Drift, Riverpod и существующий repository boundary.

Главное правило главы: cache - это data-layer detail. Widgets не должны знать, что данные пришли из SQLite. UI продолжает работать с `Moment`.

## Словарь главы

`Cache` - локальная копия данных, которую можно показать быстрее или без сети.

`Source of truth` - главный источник истины для конкретного состояния. Для Geo Moments backend остается source of truth, а SQLite хранит последнюю известную копию.

`Stale data` - данные, которые могли устареть. Например, cached like count может быть старым, пока Supabase не ответил.

`Stale-while-revalidate` - pattern: сначала показать stale cache, затем запросить fresh данные и обновить экран.

`Drift` - type-safe SQLite toolkit для Dart/Flutter. Он генерирует Dart-код для таблиц и запросов.

`Companion` - Drift-объект для insert/update. Он позволяет явно указывать значения колонок.

`Migration` в Drift - изменение локальной SQLite schema. Это не Supabase migration. Не путай эти два мира.

## 1. Что уже есть и что меняем

Сейчас flow рядом с картой такой:

```text
MapScreen
  -> nearbyMomentsProvider(center)
  -> MomentsRepository
  -> SupabaseMomentsRepository
  -> Supabase RPC nearby_moments
```

После главы станет так:

```text
MapScreen
  -> nearbyMomentsProvider(center)
  -> reads MomentsCache
  -> shows cached moments if present
  -> asks SupabaseMomentsRepository for fresh moments
  -> writes fresh moments to MomentsCache
  -> updates provider state
```

Обрати внимание: `MomentsRepository` остается domain boundary для remote commands и details. Кэш добавляется рядом с data layer, а не внутрь widgets.

Почему не кэшируем comments в этой главе: comments уже используют realtime и reply flow. Их offline semantics сложнее: нужно помнить pending comments, failed send, ordering и author state. Для главы 16 достаточно moments list/details cache.

Почему не меняем Supabase migrations: локальный SQLite schema живет в приложении. Уже примененные Supabase migration-файлы по-прежнему не переисполняются и не должны правиться ради локального кэша.

## 2. Почему Drift

Для простого key-value кэша подошел бы `shared_preferences`, но moments - структурные данные:

- `id`;
- координаты;
- текст;
- media metadata;
- author display name;
- counters;
- timestamps.

Нам нужны типы, primary key, bulk upsert и тестируемая in-memory database. Drift закрывает эти задачи.

Минимальная Drift-таблица выглядит так:

```dart
class TodoItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
}
```

Drift сгенерирует row class, companion class и helpers для typed SQL. В нашем проекте таблица будет `CachedMoments`, а наружу мы все равно будем отдавать domain entity `Moment`.

## 3. Целевая структура после главы

```text
lib/
  src/
    core/
      database/
        app_database.dart             new
        app_database.g.dart           generated
    features/
      moments/
        data/
          local/
            moments_cache.dart        new
        presentation/
          controllers/
            moments_providers.dart    updated

test/
  moments_cache_test.dart             new
  widget_test.dart                    updated if provider override changes
```

В этой главе нет новых Supabase SQL migration-файлов.

## Практика

### Шаг 1. Добавить Drift dependencies

Команда:

```bash
dart pub add drift drift_flutter path_provider dev:drift_dev dev:build_runner
```

Почему через `dart pub add`, а не вручную в `pubspec.yaml`: так pub сам подберет совместимые версии. Drift использует code generation, поэтому нужны runtime packages и dev packages.

После команды в проекте появятся примерно такие зависимости:

```yaml
dependencies:
  drift: ^2.x.x
  drift_flutter: ^0.x.x
  path_provider: ^2.x.x

dev_dependencies:
  drift_dev: ^2.x.x
  build_runner: ^2.x.x
```

`drift_flutter` открывает database на Flutter-платформах. Для tests мы будем использовать in-memory executor.

### Шаг 2. Создать локальную database

Файл:

```text
lib/src/core/database/app_database.dart
```

Код:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CachedMoments extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text().named('author_id')();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get body => text().named('text')();
  TextColumn get emotion => text().nullable()();
  TextColumn get mediaUrl => text().named('media_url').nullable()();
  TextColumn get mediaType => text().named('media_type')();
  TextColumn get authorDisplayName =>
      text().named('author_display_name').nullable()();
  TextColumn get authorAvatarUrl =>
      text().named('author_avatar_url').nullable()();
  IntColumn get likeCount =>
      integer().named('like_count').withDefault(const Constant(0))();
  IntColumn get commentCount =>
      integer().named('comment_count').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get cachedAt => dateTime().named('cached_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedMoments])
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'geo_moments_cache',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
```

Куда вставлять: это новый файл в `core/database`, потому что database - общая инфраструктура, а не часть map UI.

Почему `schemaVersion` равен `1`: это первая версия локальной SQLite schema. Если позже добавим таблицу comments cache, увеличим версию и напишем Drift migration.

Почему `cachedAt` не приходит из Supabase: это локальное время записи в cache. Оно помогает позднее показывать "updated recently" или чистить старые rows.

### Шаг 3. Сгенерировать Drift код

Команда:

```bash
dart run build_runner build
```

После генерации появится:

```text
lib/src/core/database/app_database.g.dart
```

Не редактируй `app_database.g.dart` руками. Это generated file, как Flutter l10n output.

Если analyzer ругается на `part 'app_database.g.dart';` до генерации, это ожидаемо. Сначала запускаем generator.

### Шаг 4. Добавить provider для database

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Добавь import:

```dart
import '../../../../core/database/app_database.dart';
```

Добавь provider рядом с repository providers:

```dart
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.defaults();
  ref.onDispose(database.close);
  return database;
});
```

Почему provider лежит здесь, а не в widget: database lifetime должен быть привязан к `ProviderScope`, чтобы tests могли подменять database in-memory.

Если позже появится больше features с локальным хранением, этот provider можно перенести в отдельный `core/database/app_database_provider.dart`. В этой главе оставляем изменение ближе к moments, чтобы не плодить структуру раньше времени.

### Шаг 5. Создать MomentsCache

Файл:

```text
lib/src/features/moments/data/local/moments_cache.dart
```

Код:

```dart
import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/moment.dart';

class MomentsCache {
  const MomentsCache(this._database);

  final AppDatabase _database;

  Future<List<Moment>> readNearbyMoments({int limit = 50}) async {
    final query = _database.select(_database.cachedMoments)
      ..orderBy([
        (table) => OrderingTerm.desc(table.createdAt),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_rowToDomain).toList();
  }

  Future<Moment?> readMomentById(String id) async {
    final query = _database.select(_database.cachedMoments)
      ..where((table) => table.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) {
      return null;
    }

    return _rowToDomain(row);
  }

  Future<void> replaceNearbyMoments(List<Moment> moments) async {
    final cachedAt = DateTime.now().toUtc();

    await _database.transaction(() async {
      await _database.delete(_database.cachedMoments).go();
      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _database.cachedMoments,
          moments.map((moment) => _toCompanion(moment, cachedAt)).toList(),
        );
      });
    });
  }

  Future<void> upsertMoment(Moment moment) async {
    await _database
        .into(_database.cachedMoments)
        .insertOnConflictUpdate(_toCompanion(moment, DateTime.now().toUtc()));
  }

  Moment _rowToDomain(CachedMoment row) {
    return Moment(
      id: row.id,
      authorId: row.authorId,
      latitude: row.latitude,
      longitude: row.longitude,
      text: row.body,
      mediaType: row.mediaType,
      createdAt: row.createdAt,
      emotion: row.emotion,
      mediaUrl: row.mediaUrl,
      authorDisplayName: row.authorDisplayName,
      authorAvatarUrl: row.authorAvatarUrl,
      likeCount: row.likeCount,
      commentCount: row.commentCount,
    );
  }

  CachedMomentsCompanion _toCompanion(Moment moment, DateTime cachedAt) {
    return CachedMomentsCompanion.insert(
      id: moment.id,
      authorId: moment.authorId,
      latitude: moment.latitude,
      longitude: moment.longitude,
      body: moment.text,
      mediaType: moment.mediaType,
      createdAt: moment.createdAt,
      cachedAt: cachedAt,
      emotion: Value(moment.emotion),
      mediaUrl: Value(moment.mediaUrl),
      authorDisplayName: Value(moment.authorDisplayName),
      authorAvatarUrl: Value(moment.authorAvatarUrl),
      likeCount: Value(moment.likeCount),
      commentCount: Value(moment.commentCount),
    );
  }
}
```

Почему cache возвращает `Moment`, а не `CachedMoment`: остальное приложение уже знает domain entity. Drift row - это implementation detail.

Почему `replaceNearbyMoments` удаляет старые rows: на этом этапе мы кэшируем "последний nearby result", а не строим полноценную гео-базу. Это проще и честнее для первой cache главы.

Частая ошибка: сохранить `authorId`, а потом показать его в UI как fallback. Не делай так. UI из прошлых глав уже должен показывать `authorDisplayName`, если он есть, и не показывать raw UUID.

### Шаг 6. Добавить cache provider

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

Добавь import:

```dart
import '../../data/local/moments_cache.dart';
```

Добавь provider:

```dart
final momentsCacheProvider = Provider<MomentsCache>((ref) {
  return MomentsCache(ref.watch(appDatabaseProvider));
});
```

Теперь tests могут подменять либо `appDatabaseProvider`, либо весь `momentsCacheProvider`.

### Шаг 7. Разделить remote repository и cached read flow

Файл:

```text
lib/src/features/moments/presentation/controllers/moments_providers.dart
```

В этом шаге важно не переписать весь файл. Мы меняем только provider nearby moments. Остальные providers остаются на месте.

В начале файла добавь import:

```dart
import 'dart:async';
```

После шагов 4 и 6 верх файла должен содержать примерно такие imports:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/retry_policy.dart';
import '../../../map/domain/entities/map_camera_center.dart';
import '../../data/local/moments_cache.dart';
```

Теперь найди этот provider:

```dart
final momentsRepositoryProvider = Provider<MomentsRepository>((ref) {
  return SupabaseMomentsRepository(ref.watch(supabaseClientProvider));
});
```

Его не меняй. Он остается remote repository boundary. Через него по-прежнему работают Supabase fetch, details и create moment. Tests из прошлых глав также смогут подменять `momentsRepositoryProvider` fake repository.

Сразу ниже него у тебя сейчас находится старый `nearbyMomentsProvider`:

```dart
final nearbyMomentsProvider =
    FutureProvider.family<List<Moment>, MapCameraCenter>((ref, center) {
      final repository = ref.watch(momentsRepositoryProvider);
      final retryPolicy = ref.watch(retryPolicyProvider);

      return retryPolicy.run(
        () => repository.fetchNearbyMoments(
          latitude: center.latitude,
          longitude: center.longitude,
        ),
      );
    });
```

Вот этот блок нужно заменить целиком. Не оставляй старый `FutureProvider.family` рядом с новым provider-ом, иначе в файле будет два `nearbyMomentsProvider` с одним именем.

Новый код вставь на то же место, сразу после `momentsRepositoryProvider` и перед `momentDetailsProvider`:

```dart
final nearbyMomentsProvider =
    AsyncNotifierProvider.family<
      NearbyMomentsController,
      List<Moment>,
      MapCameraCenter
    >(NearbyMomentsController.new);

class NearbyMomentsController
    extends AsyncNotifier<List<Moment>> {
  NearbyMomentsController(this._center);

  final MapCameraCenter _center;

  @override
  Future<List<Moment>> build() async {
    final cache = ref.watch(momentsCacheProvider);
    final cached = await cache.readNearbyMoments();

    if (cached.isNotEmpty) {
      unawaited(_refreshFromRemote(fallback: cached));
      return cached;
    }

    return _refreshFromRemote();
  }

  Future<List<Moment>> _refreshFromRemote({List<Moment>? fallback}) async {
    final repository = ref.read(momentsRepositoryProvider);
    final retryPolicy = ref.read(retryPolicyProvider);
    final cache = ref.read(momentsCacheProvider);

    try {
      final fresh = await retryPolicy.run(
        () => repository.fetchNearbyMoments(
          latitude: _center.latitude,
          longitude: _center.longitude,
        ),
      );

      await cache.replaceNearbyMoments(fresh);
      state = AsyncData(fresh);
      return fresh;
    } catch (error, stackTrace) {
      final cached = fallback ??
          switch (state) {
        AsyncData(:final value) => value,
        _ => null,
      };
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
```

Что в итоге остается без изменений в этом шаге:

- `momentsRepositoryProvider`;
- `momentDetailsProvider`;
- `momentMediaStorageProvider`;
- `momentLikesRepositoryProvider`;
- `momentCommentsRepositoryProvider`.

`momentDetailsProvider` обновим отдельно в шаге 8. Не смешивай эти изменения: так проще понять, что именно сломалось, если analyzer покажет ошибку.

Почему новый provider стал `AsyncNotifierProvider.family`: старый `FutureProvider.family` умеет один раз вернуть future, но ему неудобно сначала вернуть cached data, а потом позже заменить state fresh данными. `AsyncNotifier` дает controller с доступом к `state`, поэтому мы можем сделать stale-while-revalidate.

Почему у `NearbyMomentsController` есть constructor с `_center`: в `flutter_riverpod 3.x` non-generated `AsyncNotifierProvider.family` передает family argument в constructor notifier-а. Поэтому `build()` здесь без параметров, а `MapCameraCenter` хранится в поле `_center`.

Почему `unawaited`: если cache уже есть, `build` должен быстро вернуть cached data. Сетевое обновление идет следом и обновляет `state`, когда Supabase ответит.

Почему `ref.read`, а не `ref.watch` внутри `_refreshFromRemote`: это command-like refresh. Dependencies для rebuild уже прочитаны в `build`.

Почему ошибка remote refresh не должна стирать cache: если stale данные уже показаны, плохая сеть не должна превращать экран в пустую ошибку. Retry UI нужен, когда вообще нет данных.

### Шаг 8. Кэшировать details и newly created moment

`momentDetailsProvider` тоже должен стать cache-first. Если оставить обычный `FutureProvider.family` и сначала ждать Supabase, offline details будет долго показывать skeleton. Поэтому заменяем старый `FutureProvider.family` на `AsyncNotifierProvider.family`, как в шаге 7.

```dart
final momentDetailsProvider =
    AsyncNotifierProvider.family<MomentDetailsController, Moment, String>(
      MomentDetailsController.new,
    );

class MomentDetailsController extends AsyncNotifier<Moment> {
  MomentDetailsController(this._momentId);

  final String _momentId;

  @override
  Future<Moment> build() async {
    final cache = ref.watch(momentsCacheProvider);
    final cached = await cache.readMomentById(_momentId);

    if (cached != null) {
      unawaited(_refreshFromRemote(fallback: cached));
      return cached;
    }

    return _refreshFromRemote();
  }

  Future<Moment> _refreshFromRemote({Moment? fallback}) async {
    final repository = ref.read(momentsRepositoryProvider);
    final retryPolicy = ref.read(retryPolicyProvider);
    final cache = ref.read(momentsCacheProvider);

    try {
      final moment = await retryPolicy.run(
        () => repository.fetchMomentById(_momentId),
      );
      await cache.upsertMoment(moment);
      state = AsyncData(moment);
      return moment;
    } catch (error, stackTrace) {
      final cached = fallback ?? await cache.readMomentById(_momentId);
      if (cached != null) {
        return cached;
      }

      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
```

Почему cache-first здесь важен: notification tap или list tap может открыть details без сети. Если этот moment уже есть в nearby cache, лучше сразу показать cached details, а remote refresh пусть идет фоном.

Затем обнови `CreateMomentSaveController.submit()` после successful `createMoment`:

```dart
try {
  await ref.read(momentsCacheProvider).upsertMoment(moment);
} catch (error, stackTrace) {
  ref
      .read(appLoggerProvider)
      .warning(
        'Cache created moment failed',
        error: error,
        stackTrace: stackTrace,
        context: {'momentId': moment.id},
      );
}

ref.invalidate(nearbyMomentsProvider);
```

Куда вставлять: сразу после `createMoment(...)`, перед reset draft и success state.

Почему кэшируем created moment: пользователь только что создал данные. Если после этого сеть упадет, приложение все равно может показать созданный moment в последнем cache snapshot.

Почему cache write обернут в `try/catch`: успешный backend insert важнее локального cache update. Если SQLite временно недоступен, мы логируем проблему, но не показываем пользователю failure для момента, который уже создан в Supabase.

### Шаг 9. Обновить tests без хрупких provider overrides

Если `nearbyMomentsProvider` стал `AsyncNotifierProvider.family`, старый override:

```dart
nearbyMomentsProvider.overrideWith((ref, center) async => testMoments)
```

больше не подходит. Лучше подменять repository boundary:

```dart
momentsRepositoryProvider.overrideWithValue(
  FakeMomentsRepository(testMoments),
),
appDatabaseProvider.overrideWithValue(
  AppDatabase(NativeDatabase.memory()),
),
```

Для этого в `test/widget_test.dart` добавь imports:

```dart
import 'package:drift/native.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';
```

В `buildTestApp` создай database:

```dart
final database = AppDatabase(NativeDatabase.memory());
addTearDown(database.close);
```

И override:

```dart
appDatabaseProvider.overrideWithValue(database),
momentsRepositoryProvider.overrideWithValue(
  FakeMomentsRepository(testMoments),
),
```

Fake repository должен реально использоваться:

```dart
class FakeMomentsRepository implements MomentsRepository {
  const FakeMomentsRepository(this.moments);

  final List<Moment> moments;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) async {
    return moments.take(limit).toList();
  }

  @override
  Future<Moment> fetchMomentById(String id) async {
    return moments.singleWhere((moment) => moment.id == id);
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) async {
    return Moment(
      id: 'created-moment-id',
      authorId: command.authorId,
      latitude: command.latitude,
      longitude: command.longitude,
      text: command.text,
      emotion: command.emotion,
      mediaUrl: command.mediaUrl,
      mediaType: command.mediaType,
      createdAt: DateTime.utc(2026, 5, 10),
      authorDisplayName: 'Test User',
    );
  }
}
```

Почему это лучше: тест остается близким к production flow. UI вызывает provider, provider вызывает repository, fake repository отдает data. Мы не подменяем сам provider, значит не пропускаем cache code path случайно.

### Шаг 10. Добавить unit tests для кэша

Файл:

```text
test/moments_cache_test.dart
```

Код:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/moments/data/local/moments_cache.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';

void main() {
  test('stores and reads cached nearby moments', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);
    final moments = [
      Moment(
        id: 'moment-1',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Cached coffee',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
        authorDisplayName: 'Test User',
        likeCount: 2,
        commentCount: 1,
      ),
    ];

    await cache.replaceNearbyMoments(moments);

    final cached = await cache.readNearbyMoments();

    expect(cached, hasLength(1));
    expect(cached.single.id, 'moment-1');
    expect(cached.single.text, 'Cached coffee');
    expect(cached.single.authorDisplayName, 'Test User');
    expect(cached.single.likeCount, 2);
    expect(cached.single.commentCount, 1);
  });

  test('upserts moment details by id', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);

    await cache.upsertMoment(
      Moment(
        id: 'moment-1',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Initial text',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    );

    await cache.upsertMoment(
      Moment(
        id: 'moment-1',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Updated text',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    );

    final cached = await cache.readMomentById('moment-1');

    expect(cached?.text, 'Updated text');
  });
}
```

Эти tests не запускают Supabase, Mapbox или Firebase. Они проверяют только mapping между Drift row и domain entity.

### Шаг 11. Добавить provider-level test для stale cache

Файл:

```text
test/nearby_moments_cache_test.dart
```

Идея теста: если remote repository падает, но cache уже есть, provider должен вернуть cached data.

```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/map/domain/entities/map_camera_center.dart';
import 'package:geo_moments/src/features/moments/data/local/moments_cache.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';

void main() {
  test('nearby provider returns cached moments when remote fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final cache = MomentsCache(database);
    await cache.replaceNearbyMoments([
      Moment(
        id: 'cached-moment',
        authorId: 'author-1',
        latitude: -34.6037,
        longitude: -58.3816,
        text: 'Cached moment',
        mediaType: 'none',
        createdAt: DateTime.utc(2026, 5, 10),
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        momentsRepositoryProvider.overrideWithValue(
          ThrowingMomentsRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final moments = await container.read(
      nearbyMomentsProvider(MapCameraCenter.buenosAires).future,
    );

    expect(moments.single.id, 'cached-moment');
  });
}

class ThrowingMomentsRepository implements MomentsRepository {
  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw StateError('offline');
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw StateError('offline');
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw UnimplementedError();
  }
}
```

Если этот test не проходит, проверь порядок в `NearbyMomentsController.build`: сначала должен читаться cache, и только потом remote.

### Шаг 12. Не блокировать offline startup на sync профиля

Файл:

```text
lib/src/features/auth/data/repositories/supabase_auth_repository.dart
```

При ручной проверке cache есть еще один важный путь: приложение должно вообще дойти до карты. До этой главы `watchCurrentUser()` мог ждать `_syncProfile(appUser)` внутри auth stream. Online это почти незаметно, но offline запуск может зависнуть на splash, потому что profile update идет в Supabase.

Нужно изменить auth stream так, чтобы он:

- сразу отдавал локально сохраненного `currentUser`;
- запускал sync profile фоном;
- не падал и не зависал, если backend недоступен.

Добавь import:

```dart
import 'dart:async';
```

Замени `watchCurrentUser()` на:

```dart
@override
Stream<AppUser?> watchCurrentUser() async* {
  var lastKnownUser = currentUser;
  if (lastKnownUser != null) {
    unawaited(_syncProfile(lastKnownUser));
  }
  yield lastKnownUser;

  await for (final state in _client.auth.onAuthStateChange) {
    if (state.event == AuthChangeEvent.signedOut) {
      lastKnownUser = null;
      yield null;
      continue;
    }

    final user = state.session?.user;
    final appUser = _mapUser(user) ?? currentUser;

    if (appUser != null) {
      lastKnownUser = appUser;
      unawaited(_syncProfile(appUser));
      yield appUser;
      continue;
    }

    if (lastKnownUser != null) {
      yield lastKnownUser;
      continue;
    }

    yield null;
  }
}
```

Почему храним `lastKnownUser`: при offline token refresh Supabase может прислать auth event без session. Это еще не означает, что пользователь нажал sign out. Явный выход обрабатываем только через `AuthChangeEvent.signedOut`, а transient null session не должен отправлять пользователя на `/auth`.

И в `_syncProfile` лови не только `PostgrestException`, а любую ошибку:

```dart
} catch (_) {
  // The database trigger creates profiles on sign-up. If the row is not
  // available yet, or if the device is offline, auth should still continue.
  // A later auth event can sync it when the backend is reachable.
}
```

Почему это относится к cache главе: cached moments не помогут, если router остается на splash из-за auth loading. Offline read-side должен включать обе части: локальный auth session пропускает пользователя в app, а moments cache показывает последние данные на карте.

## Проверка

Команды:

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test
flutter analyze
flutter test
flutter run
```

Ручная проверка cache:

1. Запусти приложение с нормальной сетью.
2. Открой карту и дождись moments.
3. Закрой приложение полностью.
4. Отключи сеть или сломай Supabase URL в `.env` локально.
5. Запусти приложение снова.
6. Карта должна показать последние cached moments, если они уже были сохранены.
7. Верни сеть/конфиг.
8. Перезапусти или обнови центр карты.
9. Fresh moments должны снова записаться в cache.

Ручная проверка старых flows:

1. Compact phone: tap moment должен открыть bottom sheet preview.
2. Tablet/wide: tap moment должен открыть side panel, а не bottom sheet.
3. Details route `/moments/:momentId` должен открываться из notification tap и из `View details`.
4. Create moment должен по-прежнему upload/save и затем обновлять карту.
5. Location button должен центрировать карту.
6. Comments и likes должны работать из full details route.

## Частые ошибки

### Ошибка: Drift generated file редактируют руками

Причина: analyzer показывает ошибки до build runner.

Исправление: запустить:

```bash
dart run build_runner build
```

Руками правим только `app_database.dart`.

### Ошибка: UI импортирует Drift row classes

Причина: хочется быстро показать `CachedMoment` в widget.

Исправление: `MomentsCache` должен маппить row в domain `Moment`. Widgets работают только с domain/presentation моделями.

### Ошибка: cache становится source of truth для лайков/comments

Причина: cached counters показываются как окончательная правда.

Исправление: считать counters stale, пока details/likes/comments providers не получили fresh backend state. Backend остается source of truth.

### Ошибка: provider override в widget test больше не срабатывает

Причина: `nearbyMomentsProvider` поменял тип с `FutureProvider.family` на `AsyncNotifierProvider.family`.

Исправление: подменять `momentsRepositoryProvider` и `appDatabaseProvider`, а не сам nearby provider. Так fake classes реально участвуют в production-like path.

### Ошибка: cached remote failure превращается в error screen

Причина: `_refreshFromRemote` ставит `state = AsyncError(...)`, даже когда cache уже показан.

Исправление: при наличии cached data оставлять `AsyncData(cached)`. Retry UI показываем только если нет вообще никаких данных.

### Ошибка: details падает из-за optional RPC/profile join

Причина: переписали `SupabaseMomentsRepository.fetchMomentById` и потеряли fallback.

Исправление: не переписывать Supabase details logic. Добавить cache fallback вокруг существующего repository call в provider.

### Ошибка: `/moments/new` снова конфликтует с `/moments/:momentId`

Причина: случайно правили router во время cache integration.

Исправление: route `/moments/new` должен оставаться выше `/moments/:momentId`.

### Ошибка: старые Supabase migrations изменили ради cache

Причина: смешали локальную SQLite schema и remote Supabase schema.

Исправление: Drift schema живет в `app_database.dart`; Supabase migrations в этой главе не нужны.

### Ошибка: database не закрывается в tests

Причина: in-memory database создается без `addTearDown(database.close)`.

Исправление: каждый test, который создает `AppDatabase(NativeDatabase.memory())`, должен закрывать database.

## Definition of Done

- Drift dependencies добавлены через `pub`.
- `AppDatabase` и `CachedMoments` созданы.
- `app_database.g.dart` сгенерирован build runner-ом.
- `MomentsCache` читает, заменяет и upsert-ит cached moments.
- `nearbyMomentsProvider` показывает cached moments, если они есть.
- Remote refresh обновляет cache и provider state.
- Remote failure не стирает уже показанный cache.
- `momentDetailsProvider` сохраняет fresh details в cache и имеет fallback на cached moment.
- Create moment сохраняет successful result в cache.
- Compact bottom sheet preview из главы 15 не сломан.
- Tablet/wide side panel из главы 15 не сломан.
- Route order `/moments/new` перед `/moments/:momentId` сохранен.
- Details/comments остаются scrollable.
- Location button продолжает центрировать карту.
- Raw UUID автора не отображается в UI.
- Старые Supabase migration-файлы не изменены.
- Tests используют fake repositories/database overrides, которые реально участвуют в проверяемом path.
- `dart run build_runner build` проходит.
- `flutter gen-l10n` проходит.
- `dart format lib test` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.

## Что прислать на ревью

После реализации напиши:

```text
Глава 16 готова, проверь код.
```

Я буду проверять:

- что cache находится в data/core layer, а не в UI;
- что Supabase repository fallback для optional profile/RPC не сломан;
- что stale cache показывается без сети;
- что fresh remote data обновляет SQLite;
- что generated Drift file не редактировался руками;
- что tests используют in-memory database и закрывают ее;
- что fake repositories реально вызываются;
- что route order, compact preview, wide side panel, notification details route и location focus сохранились.
