// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Geo Moments';

  @override
  String get mapTitle => 'Geo Moments';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsTooltip => 'Configuración';

  @override
  String get mapPlaceholder => 'Aquí estará el mapa';

  @override
  String get nearbyMomentsTitle => 'Momentos cercanos';

  @override
  String get nearbyMomentsEmpty => 'Aquí aparecerán los momentos cercanos.';

  @override
  String get themeSettingTitle => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get languageSettingTitle => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageRussian => 'Ruso';

  @override
  String get languageSpanish => 'Español';

  @override
  String get backendSettingTitle => 'Backend';

  @override
  String backendConfigured(String host) {
    return 'Supabase configurado: $host';
  }

  @override
  String get signInWithGoogle => 'Continue with Google';

  @override
  String get signInWithApple => 'Continue with Apple';

  @override
  String get authErrorMessage => 'Could not complete sign in. Try again.';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get signOut => 'Sign out';
}
