import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeControllerProvider =
    NotifierProvider<LocaleController, LocalePreference>(LocaleController.new);

enum LocalePreference {
  system,
  english,
  russian,
  spanish;

  Locale? get locale {
    return switch (this) {
      LocalePreference.system => null,
      LocalePreference.english => const Locale('en'),
      LocalePreference.russian => const Locale('ru'),
      LocalePreference.spanish => const Locale('es'),
    };
  }
}

class LocaleController extends Notifier<LocalePreference> {
  @override
  LocalePreference build() => LocalePreference.system;

  void setLocalePreference(LocalePreference preference) {
    state = preference;
  }
}
