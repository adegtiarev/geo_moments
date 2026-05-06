import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final locationPermissionControllerProvider =
    AsyncNotifierProvider<LocationPermissionController, PermissionStatus>(
      LocationPermissionController.new,
    );

class LocationPermissionController extends AsyncNotifier<PermissionStatus> {
  @override
  Future<PermissionStatus> build() {
    return Permission.locationWhenInUse.status;
  }

  Future<PermissionStatus> request() async {
    state = const AsyncLoading();

    final nextStatus = await Permission.locationWhenInUse.request();
    state = AsyncData(nextStatus);

    return nextStatus;
  }
}
