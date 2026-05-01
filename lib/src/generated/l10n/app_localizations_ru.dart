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
}
