import 'package:flutter/material.dart';

import '../../../../core/ui/app_radius.dart';

class MapPlaceholderPanel extends StatelessWidget {
  const MapPlaceholderPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Center(
        child: Text('Map placeholder', style: textTheme.titleMedium),
      ),
    );
  }
}
