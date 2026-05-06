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
  String get nearbyMomentsLoadError => 'No se pudieron cargar los momentos.';

  @override
  String get enableLocation => 'Activar ubicación';

  @override
  String get locationPermissionDenied =>
      'El permiso de ubicación está denegado.';

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
  String get signInWithGoogle => 'Continuar con Google';

  @override
  String get signInWithApple => 'Continuar con Apple';

  @override
  String get authErrorMessage =>
      'No se pudo completar el inicio de sesión. Inténtalo de nuevo.';

  @override
  String get unknownUser => 'Usuario desconocido';

  @override
  String get signOut => 'Cerrar sesión';
}
