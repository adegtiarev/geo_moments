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
  String get enableLocation => 'Включить геолокацию';

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
}
