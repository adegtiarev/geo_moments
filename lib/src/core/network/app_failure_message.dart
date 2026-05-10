import 'package:flutter/widgets.dart';

import '../../app/localization/app_localizations_context.dart';
import 'app_failure.dart';

String messageForFailure(BuildContext context, AppFailure failure) {
  return switch (failure.kind) {
    AppFailureKind.offline => context.l10n.networkOfflineMessage,
    AppFailureKind.timeout => context.l10n.networkTimeoutMessage,
    _ => context.l10n.genericFailureMessage,
  };
}
