import 'dart:async';

import 'package:flutter/widgets.dart';

abstract interface class AppLifecycleService {
  Stream<AppLifecycleState> get states;

  void dispose();
}

class FlutterAppLifecycleService implements AppLifecycleService {
  FlutterAppLifecycleService() {
    _listener = AppLifecycleListener(onStateChange: _statesController.add);
  }

  late final AppLifecycleListener _listener;
  final _statesController = StreamController<AppLifecycleState>.broadcast();

  @override
  Stream<AppLifecycleState> get states => _statesController.stream;

  @override
  void dispose() {
    _listener.dispose();
    _statesController.close();
  }
}
