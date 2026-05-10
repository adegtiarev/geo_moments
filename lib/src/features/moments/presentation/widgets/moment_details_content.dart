import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';
import '../../domain/entities/moment_comment.dart';
import '../controllers/moment_comments_controller.dart';
import 'moment_comment_input.dart';
import 'moment_comment_list.dart';
import 'moment_media_view.dart';
import 'moment_like_button.dart';

class MomentDetailsContent extends ConsumerStatefulWidget {
  const MomentDetailsContent({required this.moment, super.key});

  final Moment moment;

  @override
  ConsumerState<MomentDetailsContent> createState() =>
      _MomentDetailsContentState();
}

class _MomentDetailsContentState extends ConsumerState<MomentDetailsContent> {
  MomentComment? _replyTarget;

  @override
  Widget build(BuildContext context) {
    final moment = widget.moment;
    final comments = ref.watch(momentCommentsControllerProvider(moment.id));
    final isSubmitting = comments.isLoading && comments.value != null;
    final textTheme = Theme.of(context).textTheme;
    final author = moment.authorDisplayName;
    final localeName = Localizations.localeOf(context).toString();
    final createdAt = DateFormat.yMMMMd(
      localeName,
    ).add_Hm().format(moment.createdAt.toLocal());

    return ListView(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      children: [
        MomentMediaView(moment: moment),
        const SizedBox(height: AppSpacing.lg),
        Text(moment.text, style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        if (author != null && author.trim().isNotEmpty) ...[
          Text(author, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
        ],
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
            MomentLikeButton(moment: moment),
            const SizedBox(width: AppSpacing.lg),
            _Metric(
              icon: Icons.mode_comment_outlined,
              value: moment.commentCount,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(context.l10n.commentsTitle, style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        comments.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => OutlinedButton.icon(
            onPressed: () {
              ref.invalidate(momentCommentsControllerProvider(moment.id));
            },
            icon: const Icon(Icons.refresh_outlined),
            label: Text(context.l10n.retry),
          ),
          data: (items) => MomentCommentList(
            comments: items,
            onReply: (comment) {
              setState(() {
                _replyTarget = comment;
              });
            },
          ),
        ),
        if (_replyTarget != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InputChip(
            label: Text(_replyTargetLabel(context, _replyTarget!)),
            onDeleted: () {
              setState(() {
                _replyTarget = null;
              });
            },
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        MomentCommentInput(
          isReply: _replyTarget != null,
          isSubmitting: isSubmitting,
          onSubmit: (body) async {
            final target = _replyTarget;
            final messenger = ScaffoldMessenger.of(context);
            final errorMessage = context.l10n.commentSendError;
            final controller = ref.read(
              momentCommentsControllerProvider(moment.id).notifier,
            );

            try {
              if (target == null) {
                await controller.addRootComment(body);
              } else {
                await controller.addReply(parentId: target.id, body: body);
              }
            } catch (_) {
              if (!mounted) {
                return;
              }

              messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
              rethrow;
            }

            if (!mounted) {
              return;
            }

            setState(() {
              _replyTarget = null;
            });
          },
        ),
      ],
    );
  }

  String _replyTargetLabel(BuildContext context, MomentComment target) {
    final author = target.authorDisplayName?.trim();
    if (author == null || author.isEmpty) {
      return context.l10n.replyToComment;
    }

    return '${context.l10n.replyToComment}: $author';
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
