import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geo_moments/src/app/app.dart';
import 'package:geo_moments/src/app/config/app_config.dart';
import 'package:geo_moments/src/app/localization/locale_controller.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/auth/presentation/controllers/auth_providers.dart';
import 'package:geo_moments/src/features/map/presentation/controllers/location_permission_controller.dart';
import 'package:geo_moments/src/features/map/presentation/widgets/map_surface_builder.dart';
import 'package:geo_moments/src/features/moments/domain/entities/create_comment_command.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment_comment.dart';
import 'package:geo_moments/src/features/moments/domain/entities/moment_like_summary.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_comments_repository.dart';
import 'package:geo_moments/src/features/moments/domain/repositories/moment_likes_repository.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moment_comments_controller.dart';
import 'package:geo_moments/src/features/moments/presentation/controllers/moments_providers.dart';
import 'package:geo_moments/src/features/notifications/data/services/push_messaging_client.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_permission_status.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_token_registration.dart';
import 'package:geo_moments/src/features/notifications/domain/repositories/push_tokens_repository.dart';
import 'package:geo_moments/src/features/notifications/presentation/controllers/push_notifications_controller.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
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

  final testMoments = [
    Moment(
      id: 'test-moment-id',
      authorId: testUser.id,
      latitude: -34.6037,
      longitude: -58.3816,
      text: 'Test coffee moment',
      mediaType: 'none',
      createdAt: DateTime.utc(2026, 5, 5),
      authorDisplayName: testUser.displayName,
    ),
  ];

  Widget buildTestApp({
    AppUser? currentUser = testUser,
    RemoteMessage? initialNotificationMessage,
  }) {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testAppConfig),
        notificationTapStreamProvider.overrideWithValue(const Stream.empty()),
        initialNotificationMessageProvider.overrideWithValue(
          Future.value(initialNotificationMessage),
        ),
        if (initialNotificationMessage == null)
          currentUserProvider.overrideWith((ref) => Stream.value(currentUser))
        else
          currentUserProvider.overrideWithValue(AsyncData(currentUser)),
        nearbyMomentsProvider.overrideWith((ref, center) async => testMoments),
        locationPermissionControllerProvider.overrideWith(
          _TestLocationPermissionController.new,
        ),
        mapSurfaceBuilderProvider.overrideWithValue(({
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
        }),
        momentDetailsProvider.overrideWith((ref, id) async {
          return testMoments.singleWhere((moment) => moment.id == id);
        }),
        momentLikesRepositoryProvider.overrideWithValue(
          FakeMomentLikesRepository(),
        ),
        momentCommentsRepositoryProvider.overrideWithValue(
          FakeMomentCommentsRepository(),
        ),
        momentCommentsRealtimeEnabledProvider.overrideWithValue(false),
        pushMessagingClientProvider.overrideWithValue(
          FakePushMessagingClient(),
        ),
        pushTokensRepositoryProvider.overrideWithValue(
          FakePushTokensRepository(),
        ),
      ],
      child: const GeoMomentsApp(),
    );
  }

  testWidgets('shows auth screen when signed out', (tester) async {
    await tester.pumpWidget(buildTestApp(currentUser: null));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('shows map screen on app start', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Geo Moments'), findsOneWidget);
    expect(find.text('Test map surface'), findsOneWidget);
    expect(find.text('Test coffee moment'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);
  });

  testWidgets('opens settings screen', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsWidgets);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Enable notifications'), findsOneWidget);
    expect(find.text('Backend'), findsOneWidget);
    expect(find.text('Supabase configured: test.supabase.co'), findsOneWidget);
  });

  testWidgets('switches app language to Russian', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DropdownMenu<LocalePreference>));
    await tester.pumpAndSettle();

    // Open the language dropdown from its editable field. Tapping the
    // DropdownMenu wrapper itself can miss after Settings becomes scrollable.
    await tester.tap(
      find.descendant(
        of: find.byType(DropdownMenu<LocalePreference>),
        matching: find.byType(TextField),
      ),
    );
    await tester.pumpAndSettle();

    // Select Russian from the menu.
    await tester.tap(find.text('Russian').last);
    await tester.pumpAndSettle();

    expect(find.text('Настройки'), findsOneWidget);
    expect(find.text('Тема'), findsOneWidget);
    expect(find.text('Язык'), findsOneWidget);
  });

  testWidgets('opens moment details from list preview', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test coffee moment'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();

    expect(find.text('Moment details'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Test coffee moment'), findsOneWidget);
    expect(find.text('Test User'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Like'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Comments'), findsOneWidget);
    expect(find.text('Write a comment'), findsOneWidget);
  });

  testWidgets('opens moment details from initial notification', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        initialNotificationMessage: const RemoteMessage(
          data: {'moment_id': 'test-moment-id'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moment details'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Test coffee moment'), findsOneWidget);
  });

  testWidgets('opens create moment screen', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create moment'));
    await tester.pumpAndSettle();

    expect(find.text('Create moment'), findsOneWidget);
    expect(find.text('What happened here?'), findsOneWidget);
    expect(find.text('Add a photo or video'), findsOneWidget);
  });

  testWidgets('requests location and sends focus command to map', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Location enabled: false'), findsOneWidget);
    expect(find.text('Location focus: 0'), findsOneWidget);

    await tester.tap(find.byTooltip('Show my location'));
    await tester.pumpAndSettle();

    expect(find.text('Location enabled: true'), findsOneWidget);
    expect(find.text('Location focus: 1'), findsOneWidget);
  });

  testWidgets('requires media and text before publishing moment', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create moment'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();

    expect(find.text('Add a short description.'), findsOneWidget);
    expect(find.text('Add media and a description first.'), findsOneWidget);
  });
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

class FakeMomentLikesRepository implements MomentLikesRepository {
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

class FakeMomentCommentsRepository implements MomentCommentsRepository {
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

class FakePushMessagingClient implements PushMessagingClient {
  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    return PushPermissionStatus.denied;
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    return PushPermissionStatus.denied;
  }

  @override
  Future<String?> getToken() async {
    return null;
  }

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class FakePushTokensRepository implements PushTokensRepository {
  @override
  Future<void> upsertToken(PushTokenRegistration registration) async {}
}
