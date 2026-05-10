import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/localization/app_localizations_context.dart';

class LocationPermissionBanner extends StatelessWidget {
  const LocationPermissionBanner({
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
    super.key,
  });

  final PermissionStatus status;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (status.isGranted || status.isLimited) {
      return const SizedBox.shrink();
    }

    final shouldOpenSettings =
        status.isPermanentlyDenied || status.isRestricted;

    return MaterialBanner(
      content: Text(
        shouldOpenSettings
            ? context.l10n.locationPermissionBlocked
            : context.l10n.locationPermissionRationale,
      ),
      actions: [
        TextButton(
          onPressed: shouldOpenSettings ? onOpenSettings : onRequest,
          child: Text(
            shouldOpenSettings
                ? context.l10n.openSettings
                : context.l10n.allowPermission,
          ),
        ),
      ],
    );
  }
}
