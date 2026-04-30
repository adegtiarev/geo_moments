import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geo_moments/src/app/localization/locale_controller.dart';

import '../../../../app/localization/app_localizations_context.dart';

class LocaleSelector extends ConsumerWidget {
  const LocaleSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localePreference = ref.watch(localeControllerProvider);

    return DropdownMenu<LocalePreference>(
      dropdownMenuEntries: [
        DropdownMenuEntry(
          value: LocalePreference.system,
          label: context.l10n.languageSystem,
        ),
        DropdownMenuEntry(
          value: LocalePreference.english,
          label: context.l10n.languageEnglish,
        ),
        DropdownMenuEntry(
          value: LocalePreference.russian,
          label: context.l10n.languageRussian,
        ),
        DropdownMenuEntry(
          value: LocalePreference.spanish,
          label: context.l10n.languageSpanish,
        ),
      ],
      initialSelection: localePreference,
      onSelected: (selection) {
        ref
            .read(localeControllerProvider.notifier)
            .setLocalePreference(selection!);
      },
    );
  }
}
