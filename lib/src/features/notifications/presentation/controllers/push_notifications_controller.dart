import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../../../core/logging/app_logger_provider.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../data/repositories/supabase_push_tokens_repository.dart';
import '../../data/services/firebase_push_messaging_client.dart';
import '../../data/services/push_messaging_client.dart';
import '../../domain/entities/push_permission_status.dart';
import '../../domain/entities/push_token_registration.dart';
import '../../domain/repositories/push_tokens_repository.dart';

final pushMessagingClientProvider = Provider<PushMessagingClient>((ref) {
  return FirebasePushMessagingClient(FirebaseMessaging.instance);
});

final pushTokensRepositoryProvider = Provider<PushTokensRepository>((ref) {
  return SupabasePushTokensRepository(ref.watch(supabaseClientProvider));
});

final pushNotificationsControllerProvider =
    AsyncNotifierProvider<PushNotificationsController, PushPermissionStatus>(
      PushNotificationsController.new,
    );

class PushNotificationsController extends AsyncNotifier<PushPermissionStatus> {
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _lastRegisteredToken;
  Future<void>? _registrationInFlight;

  @override
  Future<PushPermissionStatus> build() async {
    ref.onDispose(() {
      unawaited(_tokenRefreshSubscription?.cancel());
    });

    final client = ref.read(pushMessagingClientProvider);
    final status = await client.getPermissionStatus();
    ref
        .read(appLoggerProvider)
        .info('Push permission loaded', context: {'status': status.name});

    if (_canUseToken(status) && ref.read(currentUserProvider).value != null) {
      await _registerCurrentToken(client);
      _listenForTokenRefresh(client);
    }

    return status;
  }

  Future<void> refreshPermissionStatus() async {
    final client = ref.read(pushMessagingClientProvider);
    final status = await client.getPermissionStatus();

    if (_canUseToken(status) && ref.read(currentUserProvider).value != null) {
      await _registerCurrentToken(client);
      _listenForTokenRefresh(client);
    }

    state = AsyncData(status);
  }

  Future<void> requestAndRegister() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ref
          .read(appLoggerProvider)
          .info(
            'Push registration skipped',
            context: {'reason': 'no-signed-in-user'},
          );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(pushMessagingClientProvider);
      final status = await client.requestPermission();
      ref
          .read(appLoggerProvider)
          .info('Push permission requested', context: {'status': status.name});

      if (_canUseToken(status)) {
        await _registerCurrentToken(client);
        _listenForTokenRefresh(client);
      }

      return status;
    });
  }

  Future<void> registerIfAllowed() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      ref
          .read(appLoggerProvider)
          .info(
            'Push registration skipped',
            context: {'reason': 'no-signed-in-user'},
          );
      return;
    }

    final client = ref.read(pushMessagingClientProvider);
    final status = await client.getPermissionStatus();
    ref
        .read(appLoggerProvider)
        .info('Push permission refreshed', context: {'status': status.name});

    if (_canUseToken(status)) {
      await _registerCurrentToken(client);
      _listenForTokenRefresh(client);
    }

    state = AsyncData(status);
  }

  bool _canUseToken(PushPermissionStatus status) {
    return status == PushPermissionStatus.authorized ||
        status == PushPermissionStatus.provisional;
  }

  Future<void> _registerCurrentToken(PushMessagingClient client) async {
    final inFlight = _registrationInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final registration = _registerCurrentTokenNow(client);
    _registrationInFlight = registration;
    try {
      await registration;
    } finally {
      if (identical(_registrationInFlight, registration)) {
        _registrationInFlight = null;
      }
    }
  }

  Future<void> _registerCurrentTokenNow(PushMessagingClient client) async {
    final token = await client.getToken();
    if (token == null || token.isEmpty) {
      ref
          .read(appLoggerProvider)
          .warning(
            'Push token registration skipped',
            context: {'reason': 'firebase-returned-no-token'},
          );
      return;
    }

    if (_lastRegisteredToken == token) {
      ref
          .read(appLoggerProvider)
          .info(
            'Push token already registered',
            context: {'platform': _platform, 'tokenPrefix': _shortToken(token)},
          );
      return;
    }

    await ref
        .read(pushTokensRepositoryProvider)
        .upsertToken(PushTokenRegistration(token: token, platform: _platform));
    _lastRegisteredToken = token;
    ref
        .read(appLoggerProvider)
        .info(
          'Push token registered',
          context: {'platform': _platform, 'tokenPrefix': _shortToken(token)},
        );
  }

  void _listenForTokenRefresh(PushMessagingClient client) {
    _tokenRefreshSubscription ??= client.onTokenRefresh.listen((token) {
      ref
          .read(appLoggerProvider)
          .info(
            'Push token refreshed',
            context: {'tokenPrefix': _shortToken(token)},
          );
      unawaited(
        ref
            .read(pushTokensRepositoryProvider)
            .upsertToken(
              PushTokenRegistration(token: token, platform: _platform),
            ),
      );
    });
  }

  String get _platform {
    if (Platform.isIOS) {
      return 'ios';
    }

    return 'android';
  }

  String _shortToken(String token) {
    final length = token.length < 12 ? token.length : 12;
    return '${token.substring(0, length)}...';
  }
}
