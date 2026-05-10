enum AppFailureKind {
  offline,
  timeout,
  unauthorized,
  notFound,
  server,
  unknown,
}

class AppFailure {
  const AppFailure({required this.kind});

  final AppFailureKind kind;
}

AppFailure mapExceptionToFailure(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable')) {
    return const AppFailure(kind: AppFailureKind.offline);
  }

  if (text.contains('timeout')) {
    return const AppFailure(kind: AppFailureKind.timeout);
  }

  return const AppFailure(kind: AppFailureKind.unknown);
}
