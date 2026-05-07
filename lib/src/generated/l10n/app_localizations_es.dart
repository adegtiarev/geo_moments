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
  String get enableLocation => 'Mostrar mi ubicación';

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

  @override
  String get viewMomentDetails => 'Ver detalles';

  @override
  String get momentDetailsTitle => 'Detalles del momento';

  @override
  String get momentDetailsLoadError => 'No se pudo cargar este momento.';

  @override
  String get retry => 'Reintentar';

  @override
  String get createMomentTooltip => 'Crear momento';

  @override
  String get createMomentTitle => 'Crear momento';

  @override
  String get saveDraft => 'Guardar borrador';

  @override
  String get createMomentMediaEmpty => 'Agrega una foto o video';

  @override
  String get createMomentMediaError => 'No se pudo mostrar este medio';

  @override
  String get removeMedia => 'Quitar medio';

  @override
  String get pickPhoto => 'Elegir foto';

  @override
  String get takePhoto => 'Tomar foto';

  @override
  String get pickVideo => 'Elegir video';

  @override
  String get recordVideo => 'Grabar video';

  @override
  String get createMomentTextLabel => '¿Qué pasó aquí?';

  @override
  String get createMomentEmotionLabel => 'Emoción';

  @override
  String get createMomentTextRequired => 'Agrega una descripción breve.';

  @override
  String get createMomentDraftInvalid =>
      'Agrega un medio y una descripción primero.';

  @override
  String get createMomentDraftSaved => 'Borrador guardado.';

  @override
  String get createMomentMediaPickError => 'No se pudo elegir el medio.';
}
