import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_service.dart';

final appLifecycleServiceProvider = Provider<AppLifecycleService>((ref) {
  final service = FlutterAppLifecycleService();
  ref.onDispose(service.dispose);
  return service;
});

final appLifecycleStateProvider = StreamProvider<AppLifecycleState>((ref) {
  return ref.watch(appLifecycleServiceProvider).states;
});

final appResumedProvider = StreamProvider<void>((ref) {
  return ref
      .watch(appLifecycleServiceProvider)
      .states
      .where((state) => state == AppLifecycleState.resumed)
      .map((_) {});
});
