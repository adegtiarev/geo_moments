import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../moments/domain/entities/moment.dart';
import '../../domain/entities/map_camera_center.dart';

class MapboxMapPanel extends StatefulWidget {
  const MapboxMapPanel({
    required this.moments,
    required this.onMomentSelected,
    required this.onCameraCenterChanged,
    required this.isLocationEnabled,
    super.key,
  });

  final List<Moment> moments;
  final ValueChanged<Moment> onMomentSelected;
  final ValueChanged<MapCameraCenter> onCameraCenterChanged;
  final bool isLocationEnabled;

  @override
  State<MapboxMapPanel> createState() => _MapboxMapPanelState();
}

class _MapboxMapPanelState extends State<MapboxMapPanel> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  Timer? _cameraDebounce;
  late ViewportState _viewport;
  String? _lastStyleUri;

  @override
  void initState() {
    super.initState();

    _viewport = CameraViewportState(
      center: Point(
        coordinates: Position(
          MapCameraCenter.buenosAires.longitude,
          MapCameraCenter.buenosAires.latitude,
        ),
      ),
      zoom: 12,
    );
  }

  @override
  void didUpdateWidget(covariant MapboxMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isLocationEnabled != widget.isLocationEnabled) {
      unawaited(_syncLocationPuck());
    }

    if (oldWidget.moments != widget.moments) {
      unawaited(_renderMomentMarkers());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final nextStyleUri = _styleUriFor(context);
    if (_lastStyleUri != null && _lastStyleUri != nextStyleUri) {
      unawaited(_mapboxMap?.style.setStyleURI(nextStyleUri));
    }
    _lastStyleUri = nextStyleUri;
  }

  @override
  void dispose() {
    _cameraDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: MapWidget(
        key: const ValueKey('geoMomentsMap'),
        styleUri: _styleUriFor(context),
        viewport: _viewport,
        onMapCreated: _onMapCreated,
        onCameraChangeListener: _onCameraChanged,
      ),
    );
  }

  Future<void> _syncLocationPuck() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }

    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: widget.isLocationEnabled,
        pulsingEnabled: widget.isLocationEnabled,
      ),
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    await _syncLocationPuck();

    _circleAnnotationManager = await mapboxMap.annotations
        .createCircleAnnotationManager();

    _circleAnnotationManager?.tapEvents(
      onTap: (annotation) {
        final momentId = annotation.customData?['moment_id'];
        final selectedMoment = widget.moments.where((moment) {
          return moment.id == momentId;
        }).firstOrNull;

        if (selectedMoment != null) {
          widget.onMomentSelected(selectedMoment);
        }
      },
    );

    await _renderMomentMarkers();
  }

  void _onCameraChanged(CameraChangedEventData _) {
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 500), () async {
      final cameraState = await _mapboxMap?.getCameraState();
      final center = cameraState?.center;

      if (center == null || !mounted) {
        return;
      }

      _switchToIdleViewport();

      widget.onCameraCenterChanged(
        MapCameraCenter(
          latitude: center.coordinates.lat.toDouble(),
          longitude: center.coordinates.lng.toDouble(),
        ),
      );
    });
  }

  void _switchToIdleViewport() {
    if (_viewport is IdleViewportState) {
      return;
    }

    setState(() {
      _viewport = const IdleViewportState();
    });
  }

  Future<void> _renderMomentMarkers() async {
    final manager = _circleAnnotationManager;
    if (manager == null || !mounted) {
      return;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final markerColor = colorScheme.primary.toARGB32();
    final strokeColor = colorScheme.surface.toARGB32();

    await manager.deleteAll();

    final options = widget.moments.map((moment) {
      return CircleAnnotationOptions(
        geometry: Point(
          coordinates: Position(moment.longitude, moment.latitude),
        ),
        circleRadius: 9,
        circleColor: markerColor,
        circleStrokeColor: strokeColor,
        circleStrokeWidth: 2,
        customData: {'moment_id': moment.id},
      );
    }).toList();

    await manager.createMulti(options);
  }

  String _styleUriFor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? MapboxStyles.DARK
        : MapboxStyles.STANDARD;
  }
}
