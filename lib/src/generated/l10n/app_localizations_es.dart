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
  String get locationPermissionBlocked =>
      'La ubicación está bloqueada en los ajustes del sistema.';

  @override
  String get locationPermissionRationale =>
      'La ubicación ayuda a centrar el mapa donde estás.';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get allowPermission => 'Permitir';

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
  String get momentsLoadRetryTitle => 'No se cargaron los momentos';

  @override
  String get momentDetailsLoadRetryTitle => 'No se cargó el momento';

  @override
  String get commentsLoadRetryTitle => 'No se cargaron los comentarios';

  @override
  String get networkOfflineMessage => 'Parece que no tienes conexión.';

  @override
  String get networkTimeoutMessage => 'La red está tardando demasiado.';

  @override
  String get genericFailureMessage => 'Algo salió mal.';

  @override
  String get createMomentTooltip => 'Crear momento';

  @override
  String get createMomentTitle => 'Crear momento';

  @override
  String get saveDraft => 'Guardar borrador';

  @override
  String get publishMoment => 'Publicar';

  @override
  String get createMomentUploadingMedia => 'Subiendo medio...';

  @override
  String get createMomentSavingMoment => 'Guardando momento...';

  @override
  String get createMomentSaved => 'Momento publicado.';

  @override
  String get createMomentSaveError => 'No se pudo publicar este momento.';

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

  @override
  String get likeMoment => 'Me gusta';

  @override
  String get unlikeMoment => 'Quitar me gusta';

  @override
  String get momentLikeError => 'No se pudo actualizar el me gusta.';

  @override
  String get commentsTitle => 'Comentarios';

  @override
  String get commentsEmpty => 'Todavía no hay comentarios.';

  @override
  String get commentInputHint => 'Escribe un comentario';

  @override
  String get replyInputHint => 'Escribe una respuesta';

  @override
  String get sendComment => 'Enviar';

  @override
  String get replyToComment => 'Responder';

  @override
  String get cancelReply => 'Cancelar respuesta';

  @override
  String get commentSendError => 'No se pudo enviar el comentario.';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationsEnabled => 'Notificaciones activadas';

  @override
  String get notificationsDisabled => 'Notificaciones desactivadas';

  @override
  String get notificationsAsk => 'Activar notificaciones';

  @override
  String get notificationsPermissionDenied =>
      'Las notificaciones están bloqueadas en los ajustes del sistema.';

  @override
  String get selectedMomentTitle => 'Momento seleccionado';

  @override
  String get selectedMomentEmpty => 'Selecciona un momento en el mapa.';

  @override
  String get closeMomentPanel => 'Cerrar panel del momento';

  @override
  String get mapSemanticLabel => 'Mapa de momentos cercanos';

  @override
  String get momentMediaImageLabel => 'Contenido del momento';

  @override
  String get momentMediaVideoLabel => 'Vista previa del video del momento';

  @override
  String get momentMediaMissingLabel => 'Momento sin contenido';
}
