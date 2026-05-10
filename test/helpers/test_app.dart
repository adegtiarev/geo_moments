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
