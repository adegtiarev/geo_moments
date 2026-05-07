import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';

class MomentPreviewCard extends StatelessWidget {
  const MomentPreviewCard({
    required this.moment,
    this.onTap,
    this.trailing,
    super.key,
  });

  final Moment moment;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = moment.authorDisplayName ?? moment.authorId;
    final localeName = Localizations.localeOf(context).toString();
    final createdAt = DateFormat.yMMMd(localeName)
        .add_Hm()
        .format(moment.createdAt.toLocal());

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: const Icon(Icons.place_outlined),
      title: Text(
        moment.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author),
            Text(createdAt, style: textTheme.bodySmall),
          ],
        ),
      ),
      trailing: trailing,
    );
  }
}