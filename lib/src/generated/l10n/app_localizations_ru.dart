// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Geo Moments';

  @override
  String get mapTitle => 'Geo Moments';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsTooltip => 'Настройки';

  @override
  String get mapPlaceholder => 'Здесь будет карта';

  @override
  String get nearbyMomentsTitle => 'Моменты рядом';

  @override
  String get nearbyMomentsEmpty => 'Здесь появятся моменты рядом с вами.';

  @override
  String get nearbyMomentsLoadError => 'Не удалось загрузить моменты.';

  @override
  String get enableLocation => 'Показать мое местоположение';

  @override
  String get locationPermissionDenied => 'Доступ к геолокации запрещен.';

  @override
  String get themeSettingTitle => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Темная';

  @override
  String get languageSettingTitle => 'Язык';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageSpanish => 'Испанский';

  @override
  String get backendSettingTitle => 'Бэкенд';

  @override
  String backendConfigured(String host) {
    return 'Supabase настроен: $host';
  }

  @override
  String get signInWithGoogle => 'Войти с помощью Google';

  @override
  String get signInWithApple => 'Войти с помощью Apple';

  @override
  String get authErrorMessage => 'Не удалось войти. Попробуйте еще раз.';

  @override
  String get unknownUser => 'Неизвестный пользователь';

  @override
  String get signOut => 'Выход';

  @override
  String get viewMomentDetails => 'Открыть детали';

  @override
  String get momentDetailsTitle => 'Детали момента';

  @override
  String get momentDetailsLoadError => 'Не удалось загрузить этот момент.';

  @override
  String get retry => 'Повторить';

  @override
  String get createMomentTooltip => 'Создать момент';

  @override
  String get createMomentTitle => 'Создать момент';

  @override
  String get saveDraft => 'Сохранить черновик';

  @override
  String get publishMoment => 'Опубликовать';

  @override
  String get createMomentUploadingMedia => 'Загружаем медиа...';

  @override
  String get createMomentSavingMoment => 'Сохраняем момент...';

  @override
  String get createMomentSaved => 'Момент опубликован.';

  @override
  String get createMomentSaveError => 'Не удалось опубликовать этот момент.';

  @override
  String get createMomentMediaEmpty => 'Добавь фото или видео';

  @override
  String get createMomentMediaError => 'Не удалось показать это медиа';

  @override
  String get removeMedia => 'Удалить медиа';

  @override
  String get pickPhoto => 'Выбрать фото';

  @override
  String get takePhoto => 'Снять фото';

  @override
  String get pickVideo => 'Выбрать видео';

  @override
  String get recordVideo => 'Записать видео';

  @override
  String get createMomentTextLabel => 'Что здесь произошло?';

  @override
  String get createMomentEmotionLabel => 'Эмоция';

  @override
  String get createMomentTextRequired => 'Добавь короткое описание.';

  @override
  String get createMomentDraftInvalid => 'Сначала добавь медиа и описание.';

  @override
  String get createMomentDraftSaved => 'Черновик сохранен.';

  @override
  String get createMomentMediaPickError => 'Не удалось выбрать медиа.';

  @override
  String get likeMoment => 'Лайк';

  @override
  String get unlikeMoment => 'Убрать лайк';

  @override
  String get momentLikeError => 'Не удалось обновить лайк.';

  @override
  String get commentsTitle => 'Комментарии';

  @override
  String get commentsEmpty => 'Комментариев пока нет.';

  @override
  String get commentInputHint => 'Написать комментарий';

  @override
  String get replyInputHint => 'Написать ответ';

  @override
  String get sendComment => 'Отправить';

  @override
  String get replyToComment => 'Ответить';

  @override
  String get cancelReply => 'Отменить ответ';

  @override
  String get commentSendError => 'Не удалось отправить комментарий.';
}
