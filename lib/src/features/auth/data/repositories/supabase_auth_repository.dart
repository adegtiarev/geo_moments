import 'package:geo_moments/src/app/config/app_config.dart';
import 'package:geo_moments/src/features/auth/domain/entities/app_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final AppConfig _config;

  const SupabaseAuthRepository({
    required SupabaseClient client,
    required AppConfig config,
  }) : _client = client,
       _config = config;

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _config.authRedirectUrl,
    );
  }

  @override
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _config.authRedirectUrl,
    );
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _client.auth.onAuthStateChange.map((state) {
      return _mapUser(state.session?.user);
    });
  }

  AppUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    final metadata = user.userMetadata ?? const <String, dynamic>{};

    return AppUser(
      id: user.id,
      email: user.email,
      displayName:
          _metadataString(metadata, 'full_name') ??
          _metadataString(metadata, 'name') ??
          _metadataString(metadata, 'user_name'),
      avatarUrl:
          _metadataString(metadata, 'avatar_url') ??
          _metadataString(metadata, 'picture'),
    );
  }

  String? _metadataString(Map<String, dynamic> metadata, String key) {
    final value = metadata[key];
    return value is String ? value : null;
  }
}
