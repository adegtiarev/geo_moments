import '../../domain/entities/push_permission_status.dart';

abstract interface class PushMessagingClient {
  Future<PushPermissionStatus> getPermissionStatus();

  Future<PushPermissionStatus> requestPermission();

  Future<String?> getToken();

  Stream<String> get onTokenRefresh;
}
