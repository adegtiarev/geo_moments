# 17 Testing and Quality Gate

Статус: draft.

## Что строим

В главе 16 Geo Moments получил локальный read-side cache на Drift: карта и details умеют открываться из SQLite, remote refresh обновляет cache, а offline startup не должен зависать на синхронизации профиля.

В главе 17 мы не добавляем большую новую feature. Мы превращаем уже написанные проверки в понятный quality gate:

- приводим tests к единой структуре helper-ов и fake classes;
- усиливаем provider tests для cache, details, likes, comments, push и create flow;
- добавляем widget tests для критических маршрутов и layout-ов;
- фиксируем команды проверки в `README.md`;
- учимся отличать полезные tests от хрупких tests, которые мешают разработке.

После главы проект должен быть легче поддерживать: когда ты меняешь router, cache, comments или adaptive layout, test suite должен ловить регрессии, которые уже встречались в прошлых главах.

## Почему это важно

До этой главы Geo Moments уже достаточно сложный для маленького приложения:

```text
Supabase auth
  -> router redirect
  -> Mapbox map
  -> Supabase moments
  -> Drift cache
  -> details
  -> likes/comments/realtime
  -> Firebase notification tap
```

Если проверять это только руками, каждое изменение будет рискованным. Например, маленькая правка в `GoRouter` может снова сломать порядок `/moments/new` и `/moments/:momentId`. Правка provider-а может случайно обойти fake repository в tests. Правка details UI может опять искать текст без scroll-а.

В Android-опыте это похоже на связку unit tests, Robolectric/instrumented tests и ручного smoke test. Во Flutter у нас основа такая:

```text
unit/provider tests
  быстро проверяют domain, controllers, cache, repositories boundaries

widget tests
  проверяют UI, routing, localization, scroll, layout decisions

ручная проверка
  проверяет platform features: Mapbox, camera, OAuth, push, permissions
```

Цель главы: не покрыть все 100%. Цель - поставить защиту вокруг самых дорогих регрессий.

## Словарь главы

`Test pyramid` - идея, что быстрых unit/provider tests должно быть больше, чем тяжелых UI/manual tests.

`Unit test` - проверяет маленький кусок логики без Flutter widget tree. В нашем проекте это cache, controllers, retry decisions.

`Provider test` - unit test для Riverpod graph через `ProviderContainer`.

`Widget test` - запускает Flutter widget tree в тестовой среде и проверяет UI, navigation, gestures, scroll.

`Fake` - простая тестовая реализация interface, которая реально участвует в production-like path.

`Mock` - объект, который обычно проверяет вызовы через mocking framework. В этом курсе мы предпочитаем handwritten fakes: они проще и понятнее.

`Quality gate` - набор команд и проверок, которые должны проходить перед тем, как глава считается готовой.

`Regression test` - test, который защищает от уже найденной ошибки.

## 1. Что уже есть и что меняем

Сейчас в проекте уже есть хорошие tests:

```text
test/app_lifecycle_test.dart
test/create_moment_save_controller_test.dart
test/moments_cache_test.dart
test/nearby_moments_cache_test.dart
test/moment_details_cache_test.dart
test/moment_like_controller_test.dart
test/moment_comments_controller_test.dart
test/push_notifications_controller_test.dart
test/widget_test.dart
```

Они проверяют важные вещи:

- fake repositories реально используются через provider overrides;
- Drift cache работает через `NativeDatabase.memory()`;
- details и nearby moments открываются из cache, когда remote падает;
- compact phone сохраняет bottom sheet preview;
- tablet/wide layout использует side panel;
- location button отправляет focus command карте;
- comments/likes failures не ломают details screen;
- notification tap открывает details route.

Проблема не в отсутствии tests. Проблема в том, что часть fake classes и test setup живет прямо в `widget_test.dart`. По мере роста приложения этот файл станет слишком большим, а новые tests начнут копировать setup с ошибками.

В главе 17 мы сделаем следующий шаг: вынесем общие test helpers и добавим несколько targeted regression tests.

## 2. Почему fake classes должны быть настоящими

Плохой test может выглядеть зеленым, но ничего не защищать.

Например, если подменить сам provider:

```dart
nearbyMomentsProvider.overrideWith((ref, center) async => testMoments)
```

такой test не проверяет cache, repository boundary, retry policy и Riverpod family controller. Он проверяет только то, что UI умеет показать список, который мы вручную подсунули.

Для главы 16 это особенно опасно, потому что `nearbyMomentsProvider` стал `AsyncNotifierProvider.family`. Нам важно, чтобы test шел через реальный provider:

```text
UI
  -> nearbyMomentsProvider(center)
  -> MomentsCache
  -> MomentsRepository fake
```

Поэтому fake repository должен быть обычной реализацией `MomentsRepository`, а override должен стоять на repository boundary:

```dart
momentsRepositoryProvider.overrideWithValue(
  FakeMomentsRepository(testMoments),
)
```

Это уже знакомая идея из прошлых глав: UI не знает про Supabase, а tests не должны обходить layer, который мы хотим проверить.

## 3. Целевая структура после главы

```text
test/
  helpers/
    fake_moment_comments_repository.dart     new
    fake_moment_likes_repository.dart        new
    fake_moments_repository.dart             new
    fake_push_notifications.dart             new
    test_app.dart                            new
    test_data.dart                           new

  app_lifecycle_test.dart
  create_moment_save_controller_test.dart
  moment_comments_controller_test.dart
  moment_details_cache_test.dart
  moment_like_controller_test.dart
  moments_cache_test.dart
  nearby_moments_cache_test.dart
  push_notifications_controller_test.dart
  widget_test.dart                           updated

README.md                                    updated or created
```

Это не production code, поэтому helper-ы живут в `test/helpers`, а не в `lib`. Не импортируй test helper-ы в приложение.

## Практика

### Шаг 1. Создать test data helper

Файл:

```text
test/helpers/test_data.dart
```

Код:

```dart
import 'package:geo_moments/src/app/config/app_config.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';

const testAppConfig = AppConfig(
  supabaseUrl: 'https://test.supabase.co',
  supabaseAnonKey: 'test-anon-key',
  authRedirectUrl: 'test_redirect_url',
  mapboxAccessToken: 'test_token',
);

const testUser = AppUser(
  id: 'test-user-id',
  email: 'test@example.com',
  displayName: 'Test User',
);

final testMoment = Moment(
  id: 'test-moment-id',
  authorId: testUser.id,
  latitude: -34.6037,
  longitude: -58.3816,
  text: 'Test coffee moment',
  mediaType: 'none',
  createdAt: DateTime.utc(2026, 5, 5),
  authorDisplayName: testUser.displayName,
);

final testMoments = [testMoment];
```

Почему `final`, а не `const` у `Moment`: сейчас `Moment` constructor `const`, но `List<Moment>` часто удобнее держать как mutable-by-reference test fixture. Мы не меняем его внутри tests, но `final` дает меньше шума.

### Шаг 2. Вынести fake moments repository

Файл:

```text
test/helpers/fake_moments_repository.dart
```

Код:

```dart
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';

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

class ThrowingMomentsRepository implements MomentsRepository {
  const ThrowingMomentsRepository();

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
    throw StateError('insert failed');
  }
}
```

Почему `ThrowingMomentsRepository` полезен: cache/offline tests должны проверять не happy path, а поведение при remote failure. Это regression test для главы 16.

### Шаг 3. Вынести likes и comments fakes

Файл:

```text
test/helpers/fake_moment_likes_repository.dart
```

Код:

```dart
import 'package:geo_moments/src/features/moments/domain/entities/moment_like_summary.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_likes_repository.dart';

class FakeMomentLikesRepository implements MomentLikesRepository {
  const FakeMomentLikesRepository();

  @override
  Future<MomentLikeSummary> fetchSummary(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 0,
      isLikedByMe: false,
    );
  }

  @override
  Future<MomentLikeSummary> likeMoment(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 1,
      isLikedByMe: true,
    );
  }

  @override
  Future<MomentLikeSummary> unlikeMoment(String momentId) async {
    return MomentLikeSummary(
      momentId: momentId,
      likeCount: 0,
      isLikedByMe: false,
    );
  }
}
```

Файл:

```text
test/helpers/fake_moment_comments_repository.dart
```

Код:

```dart
import 'package:geo_moments/src/features/moments/domain/entities/create_comment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment_comment.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_comments_repository.dart';

class FakeMomentCommentsRepository implements MomentCommentsRepository {
  const FakeMomentCommentsRepository();

  @override
  Future<List<MomentComment>> fetchCommentsPage({
    required String momentId,
    int limit = 20,
    DateTime? before,
  }) async {
    return const [];
  }

  @override
  Future<MomentComment> createComment(CreateCommentCommand command) async {
    return MomentComment(
      id: 'created-comment',
      momentId: command.momentId,
      authorId: 'test-user-id',
      parentId: command.parentId,
      body: command.body,
      createdAt: DateTime.utc(2026, 5, 9),
      authorDisplayName: 'Test User',
    );
  }
}
```

Почему comments fake возвращает пустой список: widget tests details route уже проверяют, что comments section не ломается. Поведение создания comments глубже проверяется в `moment_comments_controller_test.dart`.

### Шаг 4. Вынести push fakes

Файл:

```text
test/helpers/fake_push_notifications.dart
```

Код:

```dart
import 'package:geo_moments/src/features/notifications/data/services/push_messaging_client.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_permission_status.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_token_registration.dart';
import 'package:geo_moments/src/features/notifications/domain/repositories/push_tokens_repository.dart';

class FakePushMessagingClient implements PushMessagingClient {
  const FakePushMessagingClient({
    this.permissionStatus = PushPermissionStatus.denied,
    this.token,
  });

  final PushPermissionStatus permissionStatus;
  final String? token;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    return permissionStatus;
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    return permissionStatus;
  }

  @override
  Future<String?> getToken() async {
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class FakePushTokensRepository implements PushTokensRepository {
  final registrations = <PushTokenRegistration>[];

  @override
  Future<void> upsertToken(PushTokenRegistration registration) async {
    registrations.add(registration);
  }
}
```

Почему repository fake хранит `registrations`: это позволяет в provider tests проверить не только "не упало", но и что token реально был записан.

### Шаг 5. Создать общий `pumpGeoMomentsTestApp`

Файл:

```text
test/helpers/test_app.dart
```

Код:

```dart
import 'package:drift/native.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/app/app.dart';
import 'package:geo_moments/src/app/config/app_config.dart';
import 'package:geo_moments/src/core/database/app_database.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/auth/presentation/controllers/auth_providers.dart';
import 'package:geo_moments/src/features/map/presentation/controllers/location_permission_controller.dart';
import 'package:geo_moments/src/features/map/presentation/widgets/map_surface_builder.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moment_comments_controller.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';
import 'package:geo_moments/src/features/notifications/presentation/controllers/push_notifications_controller.dart';
import 'package:permission_handler/permission_handler.dart';

import 'fake_moment_comments_repository.dart';
import 'fake_moment_likes_repository.dart';
import 'fake_moments_repository.dart';
import 'fake_push_notifications.dart';
import 'test_data.dart';

Future<void> pumpGeoMomentsTestApp(
  WidgetTester tester, {
  AppUser? currentUser = testUser,
  List<Moment>? moments,
  RemoteMessage? initialNotificationMessage,
  AppConfig appConfig = testAppConfig,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(appConfig),
        appDatabaseProvider.overrideWithValue(database),
        notificationTapStreamProvider.overrideWithValue(const Stream.empty()),
        initialNotificationMessageProvider.overrideWithValue(
          Future.value(initialNotificationMessage),
        ),
        if (initialNotificationMessage == null)
          currentUserProvider.overrideWith((ref) => Stream.value(currentUser))
        else
          currentUserProvider.overrideWithValue(AsyncData(currentUser)),
        momentsRepositoryProvider.overrideWithValue(
          FakeMomentsRepository(moments ?? testMoments),
        ),
        locationPermissionControllerProvider.overrideWith(
          _TestLocationPermissionController.new,
        ),
        mapSurfaceBuilderProvider.overrideWithValue(_fakeMapSurfaceBuilder),
        momentLikesRepositoryProvider.overrideWithValue(
          const FakeMomentLikesRepository(),
        ),
        momentCommentsRepositoryProvider.overrideWithValue(
          const FakeMomentCommentsRepository(),
        ),
        momentCommentsRealtimeEnabledProvider.overrideWithValue(false),
        pushMessagingClientProvider.overrideWithValue(
          const FakePushMessagingClient(),
        ),
        pushTokensRepositoryProvider.overrideWithValue(
          FakePushTokensRepository(),
        ),
      ],
      child: const GeoMomentsApp(),
    ),
  );
}

MapSurfaceBuilder get _fakeMapSurfaceBuilder {
  return ({
    required moments,
    required isLocationEnabled,
    required locationFocusRequestId,
    required onMomentSelected,
    required onCameraCenterChanged,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Test map surface'),
          Text('Location enabled: $isLocationEnabled'),
          Text('Location focus: $locationFocusRequestId'),
        ],
      ),
    );
  };
}

class _TestLocationPermissionController extends LocationPermissionController {
  @override
  Future<PermissionStatus> build() async {
    return PermissionStatus.denied;
  }

  @override
  Future<PermissionStatus> request() async {
    state = const AsyncData(PermissionStatus.granted);
    return PermissionStatus.granted;
  }
}

Future<void> setTestSurfaceSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
```

Куда вставлять: это новый файл. После него `widget_test.dart` должен импортировать helper и удалить локальные copies fake classes.

Почему helper сам вызывает `pumpWidget`: так каждый widget test получает одинаковый ProviderScope, in-memory Drift database и fake Mapbox surface.

Почему используем `tester.view`, а не старые `window.physicalSizeTestValue`: старые APIs deprecated. Мы уже наступали на проблему scrollable/widget tests, поэтому в новой главе не добавляем deprecated примеры.

### Шаг 6. Упростить `widget_test.dart`

Файл:

```text
test/widget_test.dart
```

Идея: после helper-ов файл должен читатьcя как сценарии пользователя, а не как набор инфраструктуры.

Минимальный пример обновленного test-а:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/generated/l10n/app_localizations.dart';

import 'helpers/test_app.dart';
import 'helpers/test_data.dart';

void main() {
  testWidgets('shows auth screen when signed out', (tester) async {
    await pumpGeoMomentsTestApp(tester, currentUser: null);
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shows map screen on app start', (tester) async {
    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    expect(find.text('Geo Moments'), findsOneWidget);
    expect(find.text('Test map surface'), findsOneWidget);
    expect(find.text(testMoment.text), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('opens moment details from initial notification', (tester) async {
    await pumpGeoMomentsTestApp(
      tester,
      initialNotificationMessage: const RemoteMessage(
        data: {'moment_id': 'test-moment-id'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moment details'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text(testMoment.text), findsOneWidget);
  });

  testWidgets('keeps compact preview sheet on phone width', (tester) async {
    await setTestSurfaceSize(tester, const Size(390, 844));

    await pumpGeoMomentsTestApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text(testMoment.text));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.viewMomentDetails), findsOneWidget);
  });
}
```

Не обязательно переписывать все tests одним огромным patch-ем. Можно сначала вынести helper-ы, запустить tests, затем удалить дублирующиеся fake classes из `widget_test.dart`.

### Шаг 7. Добавить regression test для route order

Почему нужен отдельный test: конфликт `/moments/new` и `/moments/:momentId` уже был реальной ошибкой. Widget test "opens create moment screen" косвенно это проверяет, но лучше иметь test с прямым намерением.

Добавь в `test/widget_test.dart`:

```dart
testWidgets('create moment route wins over moment details pattern', (
  tester,
) async {
  await pumpGeoMomentsTestApp(tester);
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Create moment'));
  await tester.pumpAndSettle();

  expect(find.text('Create moment'), findsOneWidget);
  expect(find.text('Moment details'), findsNothing);
});
```

Почему не проверяем внутренний список routes напрямую: router behavior важнее структуры массива. Если завтра routes будут собраны иначе, пользовательский сценарий должен остаться зеленым.

### Шаг 8. Добавить regression test для offline details без comments crash

Глава 16 разрешила открывать details из cache. Но likes/comments offline могут показывать retry/error и не должны ломать весь details screen.

Создай отдельный widget test или provider-level test. Widget test лучше ловит реальную связку UI:

```dart
testWidgets('cached details remain visible when comments are unavailable', (
  tester,
) async {
  await pumpGeoMomentsTestApp(tester);
  await tester.pumpAndSettle();

  await tester.tap(find.text(testMoment.text));
  await tester.pumpAndSettle();
  await tester.tap(find.text('View details'));
  await tester.pumpAndSettle();

  await tester.drag(find.byType(ListView), const Offset(0, -500));
  await tester.pumpAndSettle();

  expect(find.text(testMoment.text), findsOneWidget);
});
```

Если хочешь проверить именно failure comments repository, расширь `pumpGeoMomentsTestApp`, чтобы он принимал override для `momentCommentsRepositoryProvider`. Но не делай это первым шагом: helper должен остаться простым.

### Шаг 9. Усилить cache provider tests свежим remote refresh

Сейчас есть test "remote fails -> return cache". Добавим обратный сценарий: cache есть, remote отвечает fresh data, provider должен обновить state.

Файл:

```text
test/nearby_moments_cache_test.dart
```

Если этих imports еще нет, добавь их в начало файла:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';
```

Код:

```dart
test('nearby provider refreshes stale cache with remote moments', () async {
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

  final remoteMoment = Moment(
    id: 'remote-moment',
    authorId: 'author-1',
    latitude: -34.6037,
    longitude: -58.3816,
    text: 'Remote moment',
    mediaType: 'none',
    createdAt: DateTime.utc(2026, 5, 11),
  );
  final remoteResult = Completer<List<Moment>>();

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      momentsRepositoryProvider.overrideWithValue(
        ControlledNearbyMomentsRepository(remoteResult.future),
      ),
    ],
  );
  addTearDown(container.dispose);

  final provider = nearbyMomentsProvider(MapCameraCenter.buenosAires);
  final refreshed = Completer<List<Moment>>();
  final subscription = container.listen<AsyncValue<List<Moment>>>(
    provider,
    (previous, next) {
      final value = next.valueOrNull;
      if (value != null &&
          value.single.id == 'remote-moment' &&
          !refreshed.isCompleted) {
        refreshed.complete(value);
      }
    },
  );
  addTearDown(subscription.close);

  final first = await container.read(provider.future);
  expect(first.single.id, 'cached-moment');

  remoteResult.complete([remoteMoment]);

  final fresh = await refreshed.future;
  expect(fresh.single.id, 'remote-moment');
});

class ControlledNearbyMomentsRepository implements MomentsRepository {
  const ControlledNearbyMomentsRepository(this.nearbyResult);

  final Future<List<Moment>> nearbyResult;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    return nearbyResult;
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    throw UnimplementedError();
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw UnimplementedError();
  }
}
```

Почему здесь нужен `Completer`: provider сначала возвращает cache, а remote refresh идет фоном. Если fake repository отвечает мгновенно, test может стать timing-sensitive. Управляемый `Completer` делает порядок событий явным без `Future.delayed`.

### Шаг 10. Усилить details cache test свежим remote update

Файл:

```text
test/moment_details_cache_test.dart
```

Идея такая же: сначала cache, затем remote.

Если этих imports еще нет, добавь их в начало файла:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_moment_command.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moments_repository.dart';
```

```dart
test('details provider updates cached moment with remote details', () async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  final cache = MomentsCache(database);
  await cache.upsertMoment(
    Moment(
      id: 'moment-1',
      authorId: 'author-1',
      latitude: -34.6037,
      longitude: -58.3816,
      text: 'Cached details',
      mediaType: 'none',
      createdAt: DateTime.utc(2026, 5, 10),
    ),
  );

  final remoteMoment = Moment(
    id: 'moment-1',
    authorId: 'author-1',
    latitude: -34.6037,
    longitude: -58.3816,
    text: 'Remote details',
    mediaType: 'none',
    createdAt: DateTime.utc(2026, 5, 11),
    authorDisplayName: 'Remote User',
  );
  final remoteResult = Completer<Moment>();

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      momentsRepositoryProvider.overrideWithValue(
        ControlledDetailsRepository(remoteResult.future),
      ),
    ],
  );
  addTearDown(container.dispose);

  final provider = momentDetailsProvider('moment-1');
  final refreshed = Completer<Moment>();
  final subscription = container.listen<AsyncValue<Moment>>(
    provider,
    (previous, next) {
      final value = next.valueOrNull;
      if (value != null &&
          value.text == 'Remote details' &&
          !refreshed.isCompleted) {
        refreshed.complete(value);
      }
    },
  );
  addTearDown(subscription.close);

  final first = await container.read(provider.future);
  expect(first.text, 'Cached details');

  remoteResult.complete(remoteMoment);

  final fresh = await refreshed.future;
  expect(fresh.text, 'Remote details');
  expect(fresh.authorDisplayName, 'Remote User');
});

class ControlledDetailsRepository implements MomentsRepository {
  const ControlledDetailsRepository(this.detailsResult);

  final Future<Moment> detailsResult;

  @override
  Future<List<Moment>> fetchNearbyMoments({
    required double latitude,
    required double longitude,
    int limit = 50,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Moment> fetchMomentById(String id) {
    return detailsResult;
  }

  @override
  Future<Moment> createMoment(CreateMomentCommand command) {
    throw UnimplementedError();
  }
}
```

Этот test защищает важную часть stale-while-revalidate: cache ускоряет первый render, но backend остается source of truth.

### Шаг 11. Добавить README с quality gate

Файл:

```text
README.md
```

Если README уже есть, добавь раздел. Если нет - создай короткий README.

Пример:

````md
# Geo Moments

Geo Moments is a Flutter portfolio app for saving emotion-rich media moments on a map.

## Development Checks

Run these before considering a chapter complete:

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test docs/course
flutter analyze
flutter test
```

Use `flutter run` for manual checks involving Mapbox, camera/media capture, OAuth, push notifications, and platform permissions.

## Required Environment

Copy `.env.example` to `.env` and fill in the local Supabase and Mapbox values. Do not commit `.env` or service account JSON files.
````

Почему README входит в главу про testing: quality gate должен быть виден не только в course docs. Portfolio project должен объяснять, как его проверять.

### Шаг 12. Проверить generated files и secrets

Перед финальной проверкой выполни:

```bash
git status --short
```

Смысл проверки:

- `app_database.g.dart` может измениться после build runner - это нормально, если schema изменилась;
- `.env` не должен появиться в git status;
- Firebase service account JSON не должен быть добавлен;
- старые Supabase migrations не должны измениться ради локального cache или tests.

Для поиска секретов можно выполнить:

```bash
rg "private_key|FIREBASE_SERVICE_ACCOUNT|supabase_service_role|service_role" .
```

Если найдешь service account JSON или private key в репозитории, остановись и убери его из Git. В главе 13 мы уже договорились: service account живет в Supabase secret, а не в Flutter repo.

## Проверка

Команды:

```bash
dart run build_runner build
flutter gen-l10n
dart format lib test docs/course
flutter analyze
flutter test
git status --short
```

Ручная проверка после refactor tests:

1. Запусти приложение на устройстве или эмуляторе.
2. Открой карту в compact phone portrait.
3. Tap по moment должен открыть bottom sheet preview.
4. `View details` должен открыть `/moments/:momentId`.
5. На tablet/wide viewport tap должен открыть side panel.
6. Location button должен центрировать карту.
7. Details должен scroll-иться до likes/comments.
8. Offline запуск после успешного online запуска должен показать cached moments.
9. Notification tap должен открыть full details route.

## Частые ошибки

### Ошибка: provider test подменяет provider, который должен проверяться

Причина: хочется быстро вернуть data из `nearbyMomentsProvider`.

Исправление: подменяй `momentsRepositoryProvider` и `appDatabaseProvider`. Сам `nearbyMomentsProvider` должен остаться реальным.

### Ошибка: fake class объявлен, но не используется

Причина: fake написали, но override остался на другом provider-е.

Исправление: test должен падать, если fake repository бросает ошибку или возвращает другое значение. Проверяй это через visible result.

### Ошибка: widget test ищет текст ниже первого viewport

Причина: details и settings scrollable, media занимает верх экрана.

Исправление: используй `tester.ensureVisible(...)` или `tester.drag(find.byType(ListView), ...)` перед expect.

### Ошибка: tests запускают настоящий Mapbox

Причина: забыли override `mapSurfaceBuilderProvider`.

Исправление: widget tests должны использовать fake map surface. Native Mapbox проверяется вручную или отдельной emulator QA задачей.

### Ошибка: route order снова ломает `/moments/new`

Причина: route `/moments/:momentId` стоит раньше static route.

Исправление: create route должен быть выше details pattern, а widget test должен проверять, что create screen не открывает details.

### Ошибка: test использует deprecated viewport APIs

Причина: старые Flutter примеры используют `tester.binding.window.physicalSizeTestValue`.

Исправление: используй `tester.view.physicalSize` и `tester.view.devicePixelRatio`.

### Ошибка: cache test становится timing-sensitive

Причина: test ждет background refresh через произвольный `Future.delayed`.

Исправление: слушай provider state или читай provider future после invalidate/refresh. Не добавляй случайные задержки.

### Ошибка: comments/likes offline ломают весь details

Причина: error state вложенного provider-а пробрасывается выше details screen.

Исправление: details content должен оставаться видимым. Likes/comments могут показывать retry/error локально, но не должны заменить весь экран.

### Ошибка: автор опять показывается UUID

Причина: test fixtures не проверяют отсутствие raw `authorId`.

Исправление: в UI показывай `authorDisplayName`, а если его нет - не показывай автора как UUID. Добавь regression test, если этот участок снова меняется.

### Ошибка: старые migration-файлы меняются для tests

Причина: хочется поправить уже примененную SQL migration.

Исправление: примененные Supabase migrations не переисполняются. Для новой backend schema нужен новый timestamp migration. В главе 17 backend schema не меняется.

## Definition of Done

- Общие fake repositories вынесены в `test/helpers`.
- `widget_test.dart` стал короче и описывает пользовательские сценарии.
- Widget tests по-прежнему используют fake Mapbox surface.
- Tests используют `NativeDatabase.memory()` и закрывают database через `addTearDown`.
- Cache provider tests проверяют remote failure fallback.
- Cache provider tests проверяют remote refresh после stale cache.
- Details cache tests проверяют fallback и fresh update.
- Route order `/moments/new` перед `/moments/:momentId` защищен regression test-ом.
- Compact phone layout сохраняет bottom sheet preview.
- Tablet/wide layout сохраняет side panel.
- Location button продолжает отправлять focus command карте.
- Notification tap flow продолжает открывать full details route.
- Scrollable details/comments tests используют scroll-aware проверки.
- Fake classes реально используются через provider overrides.
- README содержит команды quality gate и предупреждение про `.env`/service account.
- `dart run build_runner build` проходит.
- `flutter gen-l10n` проходит.
- `dart format lib test docs/course` проходит.
- `flutter analyze` проходит.
- `flutter test` проходит.
- `git status --short` не показывает случайные secrets или лишние generated changes.

## Что прислать на ревью

После реализации напиши:

```text
Глава 17 готова, проверь код.
```

Я буду проверять:

- что helper-ы не попали в `lib`;
- что tests не обходят provider/controller, который должны проверять;
- что fake classes реально участвуют в проверяемом path;
- что scrollable UI tests не стали хрупкими;
- что route order, compact preview, side panel, location focus и notification routing защищены;
- что cache/details tests покрывают и offline fallback, и fresh refresh;
- что README quality gate совпадает с фактическими командами проекта;
- что analyze/test проходят без warnings, deprecated APIs и platform-only side effects.
