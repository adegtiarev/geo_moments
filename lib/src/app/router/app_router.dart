import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/map/presentation/screens/map_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

abstract final class AppRoutePaths {
  static const map = '/';
  static const settings = '/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutePaths.map,
    routes: [
      GoRoute(path: AppRoutePaths.map, builder: (context, state) => const MapScreen()),
      GoRoute(path: AppRoutePaths.settings, builder: (context, state) => const SettingsScreen()),
    ],
  );
});
