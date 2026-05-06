import 'package:flutter/material.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../moments/domain/entities/moment.dart';

class MomentPreviewSheet extends StatelessWidget {
  const MomentPreviewSheet({required this.moment, super.key});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(moment.text, style: textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(moment.authorDisplayName ?? moment.authorId),
              if (moment.emotion != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(moment.emotion!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
