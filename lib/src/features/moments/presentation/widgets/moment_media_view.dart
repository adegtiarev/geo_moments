import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/moment.dart';

class MomentMediaView extends StatelessWidget {
  const MomentMediaView({
    required this.moment,
    this.aspectRatio = 4 / 3,
    this.maxHeight = 360,
    super.key,
  });

  final Moment moment;
  final double aspectRatio;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final mediaUrl = moment.mediaUrl;

    if (moment.mediaType == 'image' && mediaUrl != null) {
      return Semantics(
        image: true,
        label: context.l10n.momentMediaImageLabel,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: _MediaFrame(
            aspectRatio: aspectRatio,
            maxHeight: maxHeight,
            child: Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const _MediaPlaceholder(
                  icon: Icons.broken_image_outlined,
                );
              },
            ),
          ),
        ),
      );
    }

    if (moment.mediaType == 'video' && mediaUrl != null) {
      return Semantics(
        image: true,
        label: context.l10n.momentMediaVideoLabel,
        child: _MediaFrame(
          aspectRatio: aspectRatio,
          maxHeight: maxHeight,
          child: const _MediaPlaceholder(icon: Icons.play_circle_outline),
        ),
      );
    }

    return Semantics(
      image: true,
      label: context.l10n.momentMediaMissingLabel,
      child: _MediaFrame(
        aspectRatio: aspectRatio,
        maxHeight: maxHeight,
        child: const _MediaPlaceholder(
          icon: Icons.image_not_supported_outlined,
        ),
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({
    required this.aspectRatio,
    required this.maxHeight,
    required this.child,
  });

  final double aspectRatio;
  final double maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(aspectRatio: aspectRatio, child: child),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
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
    );
  }
}
