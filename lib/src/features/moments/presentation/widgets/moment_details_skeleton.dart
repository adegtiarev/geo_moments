import 'package:flutter/material.dart';

import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';

class MomentDetailsSkeleton extends StatelessWidget {
  const MomentDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SkeletonBox(height: 220, color: color),
        const SizedBox(height: AppSpacing.lg),
        _SkeletonBox(height: 28, color: color),
        const SizedBox(height: AppSpacing.sm),
        _SkeletonBox(height: 18, color: color),
        const SizedBox(height: AppSpacing.sm),
        _SkeletonBox(height: 18, color: color),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.height,
    required this.color,
  });

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}