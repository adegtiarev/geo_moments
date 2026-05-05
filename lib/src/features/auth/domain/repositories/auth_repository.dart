import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Stream<AppUser?> watchCurrentUser();
  AppUser? get currentUser;
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signOut();
}
