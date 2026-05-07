import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../../moments/domain/entities/moment.dart';
import '../../../moments/presentation/widgets/moment_preview_card.dart';

class MomentPreviewSheet extends StatelessWidget {
  const MomentPreviewSheet({
    required this.moment,
    required this.onViewDetails,
    super.key,
  });

  final Moment moment;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MomentPreviewCard(moment: moment),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.open_in_new_outlined),
                label: Text(context.l10n.viewMomentDetails),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
