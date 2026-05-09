import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';
import '../controllers/moment_like_controller.dart';

class MomentLikeButton extends ConsumerWidget {
  const MomentLikeButton({required this.moment, super.key});

  final Moment moment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seed = (momentId: moment.id, initialLikeCount: moment.likeCount);
    final likeState = ref.watch(momentLikeControllerProvider(seed));

    ref.listen<Object?>(
      momentLikeControllerProvider(seed).select((state) => state.error),
      (previous, next) {
        if (next == null || previous == next) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.momentLikeError)));
      },
    );

    final isLiked = likeState.isLikedByMe;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isLiked
              ? context.l10n.unlikeMoment
              : context.l10n.likeMoment,
          onPressed: likeState.isBusy
              ? null
              : () {
                  ref
                      .read(momentLikeControllerProvider(seed).notifier)
                      .setLiked(!isLiked);
                },
          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('${likeState.likeCount}'),
      ],
    );
  }
}
