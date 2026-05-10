import 'package:flutter_riverpod/flutter_riverpod.dart';

class RetryPolicy {
  const RetryPolicy({this.timeout = const Duration(seconds: 12)});

  final Duration timeout;

  Future<T> run<T>(Future<T> Function() action) {
    return action().timeout(timeout);
  }
}

final retryPolicyProvider = Provider<RetryPolicy>((ref) {
  return const RetryPolicy();
});
