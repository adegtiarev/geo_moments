import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/push_token_registration.dart';
import '../../domain/repositories/push_tokens_repository.dart';

class SupabasePushTokensRepository implements PushTokensRepository {
  const SupabasePushTokensRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsertToken(PushTokenRegistration registration) async {
    await _client.rpc<void>(
      'upsert_push_token',
      params: {
        'token_value': registration.token,
        'token_platform': registration.platform,
      },
    );
  }
}
