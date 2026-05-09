import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment_comment.dart';

class MomentCommentTile extends StatelessWidget {
  const MomentCommentTile({
    required this.comment,
    required this.onReply,
    this.isReply = false,
    super.key,
  });

  final MomentComment comment;
  final ValueChanged<MomentComment> onReply;
  final bool isReply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final author = comment.authorDisplayName ?? comment.authorId;
    final localeName = Localizations.localeOf(context).toString();
    final createdAt = DateFormat.yMMMd(
      localeName,
    ).add_Hm().format(comment.createdAt.toLocal());

    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? AppSpacing.xl : 0,
        top: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(author, style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(comment.body),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(createdAt, style: textTheme.bodySmall),
              if (!isReply) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => onReply(comment),
                  child: Text(context.l10n.replyToComment),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
