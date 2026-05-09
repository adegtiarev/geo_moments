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
    return _client.auth.onAuthStateChange.asyncMap((state) async {
      final user = state.session?.user;
      final appUser = _mapUser(user);

      if (user != null && appUser != null) {
        await _syncProfile(appUser);
      }

      return appUser;
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

  Future<void> _syncProfile(AppUser user) async {
    final values = <String, dynamic>{};
    final displayName = user.displayName?.trim();
    final avatarUrl = user.avatarUrl?.trim();

    if (displayName != null && displayName.isNotEmpty) {
      values['display_name'] = displayName;
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      values['avatar_url'] = avatarUrl;
    }

    if (values.isEmpty) {
      return;
    }

    try {
      await _client.from('profiles').update(values).eq('id', user.id);
    } on PostgrestException {
      // The database trigger creates profiles on sign-up. If the row is not
      // available yet, auth should still continue and the next auth event can
      // sync it.
    }
  }
}
