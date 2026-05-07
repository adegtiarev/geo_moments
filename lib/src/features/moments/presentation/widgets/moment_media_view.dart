import 'package:flutter/material.dart';

import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';

class MomentMediaView extends StatelessWidget {
  const MomentMediaView({required this.moment, super.key});

  final Moment moment;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = moment.mediaUrl;

    if (moment.mediaType == 'image' && mediaUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const _MediaPlaceholder(icon: Icons.broken_image_outlined);
            },
          ),
        ),
      );
    }

    if (moment.mediaType == 'video' && mediaUrl != null) {
      return const _MediaPlaceholder(icon: Icons.play_circle_outline);
    }

    return const _MediaPlaceholder(icon: Icons.image_not_supported_outlined);
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Icon(
            icon,
            size: AppSpacing.xl,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
