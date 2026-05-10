import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/supabase_client_provider.dart';
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
    debugPrint('Push permission on build: $status');

    if (_canUseToken(status) && ref.read(currentUserProvider).value != null) {
      await _registerCurrentToken(client);
      _listenForTokenRefresh(client);
    }

    return status;
  }

  Future<void> requestAndRegister() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      debugPrint('Push registration skipped: no signed-in user.');
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(pushMessagingClientProvider);
      final status = await client.requestPermission();
      debugPrint('Push permission after request: $status');

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
      debugPrint('Push registration skipped: no signed-in user.');
      return;
    }

    final client = ref.read(pushMessagingClientProvider);
    final status = await client.getPermissionStatus();
    debugPrint('Push permission on startup: $status');

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
      debugPrint(
        'Push token registration skipped: Firebase returned no token.',
      );
      return;
    }

    if (_lastRegisteredToken == token) {
      debugPrint(
        'Push token already registered for $_platform: ${_shortToken(token)}',
      );
      return;
    }

    await ref
        .read(pushTokensRepositoryProvider)
        .upsertToken(PushTokenRegistration(token: token, platform: _platform));
    _lastRegisteredToken = token;
    debugPrint('Push token registered for $_platform: ${_shortToken(token)}');
  }

  void _listenForTokenRefresh(PushMessagingClient client) {
    _tokenRefreshSubscription ??= client.onTokenRefresh.listen((token) {
      debugPrint('Push token refreshed: ${_shortToken(token)}');
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
