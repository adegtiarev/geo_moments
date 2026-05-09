import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/localization/app_localizations_context.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/ui/app_breakpoints.dart';
import '../../../../core/ui/app_radius.dart';
import '../../../../core/ui/app_spacing.dart';
import '../../../moments/domain/entities/moment.dart';
import '../../../moments/presentation/controllers/moments_providers.dart';
import '../../../moments/presentation/widgets/nearby_moments_list.dart';
import '../../domain/entities/map_camera_center.dart';
import '../controllers/location_permission_controller.dart';
import '../widgets/map_surface_builder.dart';
import '../widgets/moment_preview_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapCameraCenter _center = MapCameraCenter.buenosAires;
  List<Moment> _visibleMoments = const [];
  bool _hasLoadedMoments = false;
  int _locationFocusRequestId = 0;

  @override
  Widget build(BuildContext context) {
    // 1. Moments зависят от текущего центра карты.
    final moments = ref.watch(nearbyMomentsProvider(_center));

    // 2. Через builder мы сможем подменить native Mapbox в widget tests.
    final mapBuilder = ref.watch(mapSurfaceBuilderProvider);

    // 3. Permission provider говорит, можно ли включить location puck.
    final permission = ref.watch(locationPermissionControllerProvider);
    final isLocationEnabled = permission.when(
      data: (status) => status.isGranted,
      error: (_, _) => false,
      loading: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.mapTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.createMomentTooltip,
            onPressed: () {
              context.push(
                AppRoutePaths.createMoment(
                  latitude: _center.latitude,
                  longitude: _center.longitude,
                ),
              );
            },
            icon: const Icon(Icons.add_location_alt_outlined),
          ),
          IconButton(
            tooltip: context.l10n.enableLocation,
            onPressed: _focusUserLocation,
            icon: const Icon(Icons.my_location_outlined),
          ),
          IconButton(
            tooltip: context.l10n.settingsTooltip,
            onPressed: () => context.push(AppRoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: moments.when(
        loading: () {
          if (!_hasLoadedMoments) {
            return const Center(child: CircularProgressIndicator());
          }

          return _MapContent(
            moments: _visibleMoments,
            isLocationEnabled: isLocationEnabled,
            locationFocusRequestId: _locationFocusRequestId,
            mapBuilder: mapBuilder,
            onMomentSelected: _showMomentPreview,
            onCameraCenterChanged: _updateCenter,
          );
        },
        error: (error, _) {
          if (_hasLoadedMoments) {
            return _MapContent(
              moments: _visibleMoments,
              isLocationEnabled: isLocationEnabled,
              locationFocusRequestId: _locationFocusRequestId,
              mapBuilder: mapBuilder,
              onMomentSelected: _showMomentPreview,
              onCameraCenterChanged: _updateCenter,
            );
          }

          return Center(child: Text(context.l10n.nearbyMomentsLoadError));
        },
        data: (items) {
          _visibleMoments = items;
          _hasLoadedMoments = true;

          return _MapContent(
            moments: items,
            // Этот bool пройдет дальше в MapboxMapPanel.
            isLocationEnabled: isLocationEnabled,
            locationFocusRequestId: _locationFocusRequestId,
            mapBuilder: mapBuilder,
            onMomentSelected: _showMomentPreview,
            onCameraCenterChanged: _updateCenter,
          );
        },
      ),
    );
  }

  Future<void> _focusUserLocation() async {
    final status = await ref
        .read(locationPermissionControllerProvider.notifier)
        .request();

    if (!mounted || !status.isGranted) {
      return;
    }

    setState(() {
      _locationFocusRequestId += 1;
    });
  }

  void _updateCenter(MapCameraCenter nextCenter) {
    // Не дергаем backend из-за микродвижений камеры.
    if (_center.isCloseTo(nextCenter)) {
      return;
    }

    setState(() {
      _center = nextCenter;
    });
  }

  void _showMomentPreview(Moment moment) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return MomentPreviewSheet(
          moment: moment,
          onViewDetails: () {
            Navigator.of(sheetContext).pop();
            context.push(AppRoutePaths.momentDetails(moment.id));
          },
        );
      },
    );
  }
}

class _MapContent extends StatelessWidget {
  const _MapContent({
    required this.moments,
    required this.isLocationEnabled,
    required this.locationFocusRequestId,
    required this.mapBuilder,
    required this.onMomentSelected,
    required this.onCameraCenterChanged,
  });

  final List<Moment> moments;
  final bool isLocationEnabled;
  final int locationFocusRequestId;
  final MapSurfaceBuilder mapBuilder;
  final ValueChanged<Moment> onMomentSelected;
  final ValueChanged<MapCameraCenter> onCameraCenterChanged;

  @override
  Widget build(BuildContext context) {
    final map = mapBuilder(
      moments: moments,
      isLocationEnabled: isLocationEnabled,
      locationFocusRequestId: locationFocusRequestId,
      onMomentSelected: onMomentSelected,
      onCameraCenterChanged: onCameraCenterChanged,
    );

    final sidePanel = _NearbyMomentsPanel(
      moments: moments,
      onMomentSelected: onMomentSelected,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = AppBreakpoints.isTabletWidth(constraints.maxWidth);

            if (isTablet) {
              return Row(
                children: [
                  Expanded(child: map),
                  const SizedBox(width: AppSpacing.lg),
                  SizedBox(width: 360, child: sidePanel),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: map),
                const SizedBox(height: AppSpacing.md),
                SizedBox(height: 220, child: sidePanel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NearbyMomentsPanel extends StatelessWidget {
  const _NearbyMomentsPanel({
    required this.moments,
    required this.onMomentSelected,
  });

  final List<Moment> moments;
  final ValueChanged<Moment> onMomentSelected;

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
            Expanded(
              child: NearbyMomentsList(
                moments: moments,
                onMomentTap: onMomentSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
