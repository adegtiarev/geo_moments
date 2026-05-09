// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Geo Moments';

  @override
  String get mapTitle => 'Geo Moments';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsTooltip => 'Settings';

  @override
  String get mapPlaceholder => 'Map placeholder';

  @override
  String get nearbyMomentsTitle => 'Nearby moments';

  @override
  String get nearbyMomentsEmpty => 'Moments around you will appear here.';

  @override
  String get nearbyMomentsLoadError => 'Could not load moments.';

  @override
  String get enableLocation => 'Show my location';

  @override
  String get locationPermissionDenied => 'Location permission is denied.';

  @override
  String get themeSettingTitle => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageSettingTitle => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get backendSettingTitle => 'Backend';

  @override
  String backendConfigured(String host) {
    return 'Supabase configured: $host';
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

  @override
  String get viewMomentDetails => 'View details';

  @override
  String get momentDetailsTitle => 'Moment details';

  @override
  String get momentDetailsLoadError => 'Could not load this moment.';

  @override
  String get retry => 'Retry';

  @override
  String get createMomentTooltip => 'Create moment';

  @override
  String get createMomentTitle => 'Create moment';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get publishMoment => 'Publish';

  @override
  String get createMomentUploadingMedia => 'Uploading media...';

  @override
  String get createMomentSavingMoment => 'Saving moment...';

  @override
  String get createMomentSaved => 'Moment published.';

  @override
  String get createMomentSaveError => 'Could not publish this moment.';

  @override
  String get createMomentMediaEmpty => 'Add a photo or video';

  @override
  String get createMomentMediaError => 'Could not show this media';

  @override
  String get removeMedia => 'Remove media';

  @override
  String get pickPhoto => 'Pick photo';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get pickVideo => 'Pick video';

  @override
  String get recordVideo => 'Record video';

  @override
  String get createMomentTextLabel => 'What happened here?';

  @override
  String get createMomentEmotionLabel => 'Emotion';

  @override
  String get createMomentTextRequired => 'Add a short description.';

  @override
  String get createMomentDraftInvalid => 'Add media and a description first.';

  @override
  String get createMomentDraftSaved => 'Draft saved.';

  @override
  String get createMomentMediaPickError => 'Could not pick media.';
}
