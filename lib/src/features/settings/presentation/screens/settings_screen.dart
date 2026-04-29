import 'package:flutter/material.dart';
import 'package:geo_moments/src/features/settings/presentation/widgets/theme_mode_selector.dart';

import '../../../../core/ui/app_spacing.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme'),
                SizedBox(height: AppSpacing.sm),
                ThemeModeSelector(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
