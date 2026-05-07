import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/app/router/splash_screen.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_providers.dart';
import '../../features/auth/presentation/screens/auth_screen.dart';
import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/moments/presentation/screens/moment_details_screen.dart';
import '../../features/moments/presentation/screens/create_moment_screen.dart';

abstract final class AppRoutePaths {
  static const splash = '/splash';
  static const auth = '/auth';
  static const map = '/';
  static const settings = '/settings';
  static const momentDetailsPattern = '/moments/:momentId';
  static String momentDetails(String momentId) {
    return '/moments/${Uri.encodeComponent(momentId)}';
  }

  static const createMoment = '/moments/new';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final currentUser = ref.watch(currentUserProvider);

  return GoRouter(
    initialLocation: AppRoutePaths.splash,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isAuthRoute = location == AppRoutePaths.auth;
      final isSplashRoute = location == AppRoutePaths.splash;

      return currentUser.when(
        loading: () => isSplashRoute ? null : AppRoutePaths.splash,
        error: (_, _) => isAuthRoute ? null : AppRoutePaths.auth,
        data: (user) {
          final isSignedIn = user != null;

          if (!isSignedIn) {
            return isAuthRoute ? null : AppRoutePaths.auth;
          }

          if (isAuthRoute || isSplashRoute) {
            return AppRoutePaths.map;
          }

          return null;
        },
      );
    },
    routes: [
      GoRoute(
        path: AppRoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.auth,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.map,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.createMoment,
        builder: (context, state) => const CreateMomentScreen(),
      ),
      GoRoute(
        path: AppRoutePaths.momentDetailsPattern,
        builder: (context, state) {
          final momentId = state.pathParameters['momentId']!;

          return MomentDetailsScreen(momentId: momentId);
        },
      ),
    ],
  );
});
