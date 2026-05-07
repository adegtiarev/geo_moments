import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';
import 'moment_media_view.dart';

class MomentDetailsContent extends StatelessWidget {
  const MomentDetailsContent({required this.moment, super.key});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = moment.authorDisplayName ?? moment.authorId;
    final localeName = Localizations.localeOf(context).toString();
    final createdAt = DateFormat.yMMMMd(
      localeName,
    ).add_Hm().format(moment.createdAt.toLocal());

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        MomentMediaView(moment: moment),
        const SizedBox(height: AppSpacing.lg),
        Text(moment.text, style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(author, style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(createdAt, style: textTheme.bodySmall),
        if (moment.emotion != null) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [Chip(label: Text(moment.emotion!))],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _Metric(icon: Icons.favorite_border, value: moment.likeCount),
            const SizedBox(width: AppSpacing.lg),
            _Metric(
              icon: Icons.mode_comment_outlined,
              value: moment.commentCount,
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.xs),
        Text('$value'),
      ],
    );
  }
}
