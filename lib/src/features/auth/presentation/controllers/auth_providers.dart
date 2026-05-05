import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/app/config/app_config.dart';
import 'package:geo_moments/src/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:geo_moments/src/features/auth/domain/repositories/auth_repository.dart';

import '../../../../core/backend/supabase_client_provider.dart';
import '../../domain/entities/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(
    client: ref.watch(supabaseClientProvider),
    config: ref.watch(appConfigProvider),
  );
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.watchCurrentUser();
});

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithGoogle(),
    );
  }

  Future<void> signInWithApple() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInWithApple(),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signOut(),
    );
  }
}
