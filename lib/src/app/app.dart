import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/app/localization/app_localizations_context.dart';
import 'package:geo_moments/src/app/router/app_router.dart';
import 'package:geo_moments/src/app/theme/app_theme.dart';
import 'package:geo_moments/src/app/theme/theme_mode_controller.dart';
import 'package:geo_moments/src/generated/l10n/app_localizations.dart';

import 'localization/locale_controller.dart';

class GeoMomentsApp extends ConsumerWidget {
  const GeoMomentsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
}
