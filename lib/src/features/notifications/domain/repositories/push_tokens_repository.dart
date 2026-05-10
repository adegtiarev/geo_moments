import '../entities/push_token_registration.dart';

abstract interface class PushTokensRepository {
  Future<void> upsertToken(PushTokenRegistration registration);
}
