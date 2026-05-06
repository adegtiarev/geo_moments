import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../moments/domain/entities/moment.dart';
import '../../domain/entities/map_camera_center.dart';
import 'mapbox_map_panel.dart';

typedef MapSurfaceBuilder =
    Widget Function({
      required List<Moment> moments,
      required bool isLocationEnabled,
      required ValueChanged<Moment> onMomentSelected,
      required ValueChanged<MapCameraCenter> onCameraCenterChanged,
    });

final mapSurfaceBuilderProvider = Provider<MapSurfaceBuilder>((ref) {
  return ({
    required moments,
    required isLocationEnabled,
    required onMomentSelected,
    required onCameraCenterChanged,
  }) {
    return MapboxMapPanel(
      moments: moments,
      isLocationEnabled: isLocationEnabled,
      onMomentSelected: onMomentSelected,
      onCameraCenterChanged: onCameraCenterChanged,
    );
  };
});
