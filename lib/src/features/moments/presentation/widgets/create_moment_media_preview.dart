import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../domain/entities/picked_moment_media.dart';

class CreateMomentMediaPreview extends StatelessWidget {
  const CreateMomentMediaPreview({
    required this.media,
    required this.onClear,
    super.key,
  });

  final PickedMomentMedia? media;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.min(constraints.maxWidth * 3 / 4, 320.0);

        return SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (media == null)
                    _EmptyPreview(label: context.l10n.createMomentMediaEmpty)
                  else if (media!.kind == MomentMediaKind.image)
                    Image.file(
                      File(media!.path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _EmptyPreview(
                          label: context.l10n.createMomentMediaError,
                        );
                      },
                    )
                  else
                    _VideoPreview(fileName: media!.name),
                  if (media != null)
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: IconButton.filledTonal(
                        tooltip: context.l10n.removeMedia,
                        onPressed: onClear,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: AppSpacing.xl,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatelessWidget {
  const _VideoPreview({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
