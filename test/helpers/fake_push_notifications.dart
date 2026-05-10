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
