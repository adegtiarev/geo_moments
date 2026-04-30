import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/app/theme/theme_mode_controller.dart';

import '../../../../app/localization/app_localizations_context.dart';

class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);

    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.system,
          label: Text(context.l10n.themeSystem),
          icon: Icon(Icons.brightness_auto_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          label: Text(context.l10n.themeLight),
          icon: Icon(Icons.light_mode_outlined),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text(context.l10n.themeDark),
          icon: Icon(Icons.dark_mode_outlined),
        ),
      ],
      selected: {themeMode},
      onSelectionChanged: (selection) {
        ref
            .read(themeModeControllerProvider.notifier)
            .setThemeMode(selection.single);
      },
    );
  }
}
