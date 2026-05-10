import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:geo_moments/src/features/auth/presentation/controllers/auth_providers.dart';
import 'package:geo_moments/src/features/notifications/data/services/push_messaging_client.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_permission_status.dart';
import 'package:geo_moments/src/features/notifications/domain/entities/push_token_registration.dart';
import 'package:geo_moments/src/features/notifications/domain/repositories/push_tokens_repository.dart';
import 'package:geo_moments/src/features/notifications/presentation/controllers/push_notifications_controller.dart';

void main() {
  test(
    'requestAndRegister stores token when permission is authorized',
    () async {
      final messaging = FakePushMessagingClient(
        permissionStatus: PushPermissionStatus.authorized,
        token: 'fcm-token',
      );
      final repository = FakePushTokensRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(
            const AsyncData(AppUser(id: 'user-id', email: 'test@example.com')),
          ),
          pushMessagingClientProvider.overrideWithValue(messaging),
          pushTokensRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await messaging.dispose();
      });

      await container
          .read(pushNotificationsControllerProvider.notifier)
          .requestAndRegister();

      expect(repository.saved, hasLength(1));
      expect(repository.saved.single.token, 'fcm-token');
    },
  );

  test(
    'requestAndRegister does not store token when permission is denied',
    () async {
      final messaging = FakePushMessagingClient(
        permissionStatus: PushPermissionStatus.denied,
        token: 'fcm-token',
      );
      final repository = FakePushTokensRepository();
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(
            const AsyncData(AppUser(id: 'user-id', email: 'test@example.com')),
          ),
          pushMessagingClientProvider.overrideWithValue(messaging),
          pushTokensRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await messaging.dispose();
      });

      await container
          .read(pushNotificationsControllerProvider.notifier)
          .requestAndRegister();

      expect(repository.saved, isEmpty);
    },
  );

  test('stores refreshed token after registration', () async {
    final messaging = FakePushMessagingClient(
      permissionStatus: PushPermissionStatus.authorized,
      token: 'initial-token',
    );
    final repository = FakePushTokensRepository();
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(
          const AsyncData(AppUser(id: 'user-id', email: 'test@example.com')),
        ),
        pushMessagingClientProvider.overrideWithValue(messaging),
        pushTokensRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await messaging.dispose();
    });

    await container
        .read(pushNotificationsControllerProvider.notifier)
        .requestAndRegister();

    messaging.refreshToken('refreshed-token');
    await Future<void>.delayed(Duration.zero);

    expect(repository.saved.map((registration) => registration.token), [
      'initial-token',
      'refreshed-token',
    ]);
  });
}

class FakePushMessagingClient implements PushMessagingClient {
  FakePushMessagingClient({
    required this.permissionStatus,
    required this.token,
  });

  final PushPermissionStatus permissionStatus;
  final String? token;
  final _tokenRefreshController = StreamController<String>.broadcast();

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
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  void refreshToken(String token) {
    _tokenRefreshController.add(token);
  }

  Future<void> dispose() {
    return _tokenRefreshController.close();
  }
}

class FakePushTokensRepository implements PushTokensRepository {
  final saved = <PushTokenRegistration>[];

  @override
  Future<void> upsertToken(PushTokenRegistration registration) async {
    saved.add(registration);
  }
}
