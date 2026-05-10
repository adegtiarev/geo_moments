import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geo_moments/src/core/lifecycle/app_lifecycle_providers.dart';
import 'package:geo_moments/src/core/lifecycle/app_lifecycle_service.dart';

void main() {
  test('appResumedProvider emits when the app resumes', () async {
    final lifecycle = FakeAppLifecycleService();
    final container = ProviderContainer(
      overrides: [appLifecycleServiceProvider.overrideWithValue(lifecycle)],
    );
    final events = <AsyncValue<void>>[];
    final subscription = container.listen<AsyncValue<void>>(
      appResumedProvider,
      (previous, next) {
        events.add(next);
      },
    );

    addTearDown(subscription.close);
    addTearDown(container.dispose);
    addTearDown(lifecycle.dispose);

    lifecycle.resume();
    await Future<void>.delayed(Duration.zero);

    expect(events.where((event) => event.hasValue), isNotEmpty);
  });
}

class FakeAppLifecycleService implements AppLifecycleService {
  final _controller = StreamController<AppLifecycleState>.broadcast();

  @override
  Stream<AppLifecycleState> get states => _controller.stream;

  void resume() {
    _controller.add(AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
