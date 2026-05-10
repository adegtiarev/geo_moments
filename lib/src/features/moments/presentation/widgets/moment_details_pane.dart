import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/network/app_failure_message.dart';
import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../controllers/moments_providers.dart';
import 'moment_details_content.dart';
import 'moment_details_skeleton.dart';
import 'retry_error_view.dart';

class MomentDetailsPane extends ConsumerWidget {
  const MomentDetailsPane({
    required this.momentId,
    required this.onClose,
    super.key,
  });

  final String? momentId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(
          children: [
            _PaneHeader(onClose: onClose, canClose: momentId != null),
            const Divider(height: 1),
            Expanded(
              child: momentId == null
                  ? const _EmptyMomentSelection()
                  : _LoadedMomentPane(momentId: momentId!),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.onClose, required this.canClose});

  final VoidCallback onClose;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.selectedMomentTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: context.l10n.closeMomentPanel,
            onPressed: canClose ? onClose : null,
            icon: const Icon(Icons.close_outlined),
          ),
        ],
      ),
    );
  }
}

class _LoadedMomentPane extends ConsumerWidget {
  const _LoadedMomentPane({required this.momentId});

  final String momentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moment = ref.watch(momentDetailsProvider(momentId));

    return moment.when(
      loading: () => const MomentDetailsSkeleton(),
      error: (error, stackTrace) {
        final failure = mapExceptionToFailure(error);
        return RetryErrorView(
          title: context.l10n.momentDetailsLoadRetryTitle,
          message: messageForFailure(context, failure),
          onRetry: () {
            ref.invalidate(momentDetailsProvider(momentId));
          },
        );
      },
      data: (moment) => MomentDetailsContent(moment: moment),
    );
  }
}

class _EmptyMomentSelection extends StatelessWidget {
  const _EmptyMomentSelection();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          context.l10n.selectedMomentEmpty,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
