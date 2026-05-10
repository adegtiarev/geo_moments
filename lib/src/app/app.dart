import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/app/localization/app_localizations_context.dart';
import 'package:geo_moments/src/app/router/app_router.dart';
import 'package:geo_moments/src/app/theme/app_theme.dart';
import 'package:geo_moments/src/app/theme/theme_mode_controller.dart';
import 'package:geo_moments/src/generated/l10n/app_localizations.dart';

import '../features/auth/presentation/controllers/auth_providers.dart';
import '../features/notifications/presentation/controllers/push_notifications_controller.dart';
import 'localization/locale_controller.dart';

final notificationTapStreamProvider = Provider<Stream<RemoteMessage>>((ref) {
  return FirebaseMessaging.onMessageOpenedApp;
});

final initialNotificationMessageProvider = Provider<Future<RemoteMessage?>>((
  ref,
) {
  return FirebaseMessaging.instance.getInitialMessage();
});

class GeoMomentsApp extends ConsumerStatefulWidget {
  const GeoMomentsApp({super.key});

  @override
  ConsumerState<GeoMomentsApp> createState() => _GeoMomentsAppState();
}

class _GeoMomentsAppState extends ConsumerState<GeoMomentsApp> {
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _pendingMomentId;

  @override
  void initState() {
    super.initState();

    _openedSubscription = ref
        .read(notificationTapStreamProvider)
        .listen(_openMessage);

    unawaited(_openInitialMessage());
  }

  @override
  void dispose() {
    unawaited(_openedSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          unawaited(
            ref
                .read(pushNotificationsControllerProvider.notifier)
                .registerIfAllowed(),
          );
          _openPendingMoment();
        }
      });
    });

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final localePreference = ref.watch(localeControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localePreference.locale,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }

  Future<void> _openInitialMessage() async {
    final message = await ref.read(initialNotificationMessageProvider);
    if (message != null) {
      final momentId = _momentIdFromMessage(message);
      if (momentId == null) {
        return;
      }

      _pendingMomentId = momentId;
      try {
        await ref.read(currentUserProvider.future);
      } catch (_) {
        return;
      }

      if (mounted) {
        _openPendingMoment();
      }
    }
  }

  void _openMessage(RemoteMessage message) {
    final momentId = _momentIdFromMessage(message);
    if (momentId == null) {
      return;
    }

    _pendingMomentId = momentId;
    _openPendingMoment();
  }

  void _openPendingMoment() {
    final momentId = _pendingMomentId;
    if (momentId == null) {
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      return;
    }

    _pendingMomentId = null;
    ref.read(appRouterProvider).push(AppRoutePaths.momentDetails(momentId));
  }

  String? _momentIdFromMessage(RemoteMessage message) {
    final momentId = message.data['moment_id'];
    if (momentId is! String || momentId.isEmpty) {
      return null;
    }

    return momentId;
  }
}
