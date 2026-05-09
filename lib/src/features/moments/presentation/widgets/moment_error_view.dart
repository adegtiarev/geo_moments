import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';

class MomentErrorView extends StatelessWidget {
  const MomentErrorView({required this.onRetry, this.error, super.key});

  final VoidCallback onRetry;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.momentDetailsLoadError,
              textAlign: TextAlign.center,
            ),
            if (kDebugMode && error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
