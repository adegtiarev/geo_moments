import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/push_permission_status.dart';
import 'push_messaging_client.dart';

class FirebasePushMessagingClient implements PushMessagingClient {
  FirebasePushMessagingClient(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  Future<PushPermissionStatus> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<PushPermissionStatus> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<String?> getToken() {
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  PushPermissionStatus _mapAuthorizationStatus(AuthorizationStatus status) {
    return switch (status) {
      AuthorizationStatus.authorized => PushPermissionStatus.authorized,
      AuthorizationStatus.denied => PushPermissionStatus.denied,
      AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
      AuthorizationStatus.provisional => PushPermissionStatus.provisional,
    };
  }
}
