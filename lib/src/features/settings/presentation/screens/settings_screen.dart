import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/app/localization/app_localizations_context.dart';
import 'package:geo_moments/src/features/settings/presentation/widgets/theme_mode_selector.dart';

import '../../../../core/ui/app_spacing.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../widgets/backend_status_tile.dart';
import '../widgets/current_user_tile.dart';
import '../widgets/locale_selector.dart';
import '../../../notifications/presentation/widgets/notification_status_tile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(context.l10n.themeSettingTitle),
            const SizedBox(height: AppSpacing.sm),
            const ThemeModeSelector(),
            const SizedBox(height: AppSpacing.lg),
            Text(context.l10n.languageSettingTitle),
            const SizedBox(height: AppSpacing.sm),
            const LocaleSelector(),
            const SizedBox(height: AppSpacing.lg),
            const NotificationStatusTile(),
            const SizedBox(height: AppSpacing.lg),
            const BackendStatusTile(),
            const SizedBox(height: AppSpacing.lg),
            CurrentUserTile(),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout_outlined),
              label: Text(context.l10n.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
