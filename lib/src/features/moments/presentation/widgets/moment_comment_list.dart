import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment_comment.dart';
import 'moment_comment_tile.dart';

class MomentCommentList extends StatelessWidget {
  const MomentCommentList({
    required this.comments,
    required this.onReply,
    super.key,
  });

  final List<MomentComment> comments;
  final ValueChanged<MomentComment> onReply;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(context.l10n.commentsEmpty),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final comment in comments) ...[
          MomentCommentTile(comment: comment, onReply: onReply),
          for (final reply in comment.replies)
            MomentCommentTile(comment: reply, onReply: onReply, isReply: true),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
