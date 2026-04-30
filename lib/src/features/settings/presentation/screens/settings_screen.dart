import 'package:flutter/material.dart';
import 'package:geo_moments/src/app/localization/app_localizations_context.dart';
import 'package:geo_moments/src/features/settings/presentation/widgets/theme_mode_selector.dart';

import '../../../../core/ui/app_spacing.dart';
import '../widgets/locale_selector.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.themeSettingTitle),
                const SizedBox(height: AppSpacing.sm),
                const ThemeModeSelector(),

                const SizedBox(height: AppSpacing.lg),
                Text(context.l10n.languageSettingTitle),
                const SizedBox(height: AppSpacing.sm),
                const LocaleSelector(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
