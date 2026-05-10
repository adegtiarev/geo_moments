import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_logger.dart';
import 'debug_app_logger.dart';

final appLoggerProvider = Provider<AppLogger>((ref) {
  return const DebugAppLogger();
});
