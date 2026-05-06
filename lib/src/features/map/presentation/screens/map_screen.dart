import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:geo_moments/src/core/ui/app_radius.dart';
import 'package:geo_moments/src/core/ui/app_spacing.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/ui/app_breakpoints.dart';
import '../../../moments/presentation/widgets/nearby_moments_list.dart';
import '../widgets/map_placeholder_panel.dart';

class MapScreen extends StatelessWidget {
  @Preview(
    name: 'MapScreen - phone',
    size: Size(300, 600),
    brightness: Brightness.light,
  )
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mapTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.settingsTooltip,
            onPressed: () => context.push(AppRoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = AppBreakpoints.isTabletWidth(
                constraints.maxWidth,
              );
              if (isTablet) {
                return const _TabletMapLayout();
              }

              return const _PhoneMapLayout();
            },
          ),
        ),
      ),
    );
  }
}

class _PhoneMapLayout extends StatelessWidget {
  const _PhoneMapLayout();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Expanded(child: MapPlaceholderPanel()),
          SizedBox(height: AppSpacing.md),
          SizedBox(height: 220, child: _NearbyMomentsPanel()),
        ],
      ),
    );
  }
}

class _TabletMapLayout extends StatelessWidget {
  const _TabletMapLayout();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(flex: 3, child: MapPlaceholderPanel()),
          SizedBox(width: AppSpacing.lg),
          SizedBox(width: 360, child: _NearbyMomentsPanel()),
        ],
      ),
    );
  }
}

class _NearbyMomentsPanel extends StatelessWidget {
  const _NearbyMomentsPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.nearbyMomentsTitle, style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const Expanded(child: NearbyMomentsList()),
          ],
        ),
      ),
    );
  }
}
