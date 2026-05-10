import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('ru'),
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'Geo Moments'**
  String get appTitle;

  /// Main map screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Geo Moments'**
  String get mapTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Tooltip for the settings button
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTooltip;

  /// Temporary placeholder text for the future map
  ///
  /// In en, this message translates to:
  /// **'Map placeholder'**
  String get mapPlaceholder;

  /// Title for the nearby moments summary panel
  ///
  /// In en, this message translates to:
  /// **'Nearby moments'**
  String get nearbyMomentsTitle;

  /// Empty state text for nearby moments
  ///
  /// In en, this message translates to:
  /// **'Moments around you will appear here.'**
  String get nearbyMomentsEmpty;

  /// Error state text when nearby moments cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Could not load moments.'**
  String get nearbyMomentsLoadError;

  /// Tooltip for the button that requests location permission and centers the map on the user
  ///
  /// In en, this message translates to:
  /// **'Show my location'**
  String get enableLocation;

  /// Message shown when location permission is denied
  ///
  /// In en, this message translates to:
  /// **'Location permission is denied.'**
  String get locationPermissionDenied;

  /// No description provided for @locationPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked in system settings.'**
  String get locationPermissionBlocked;

  /// No description provided for @locationPermissionRationale.
  ///
  /// In en, this message translates to:
  /// **'Location helps center the map on where you are.'**
  String get locationPermissionRationale;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @allowPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allowPermission;

  /// Settings row title for theme selection
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeSettingTitle;

  /// System theme mode option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Light theme mode option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme mode option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Settings row title for language selection
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSettingTitle;

  /// System language option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Russian language option
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// Spanish language option
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// Settings section title for backend status
  ///
  /// In en, this message translates to:
  /// **'Backend'**
  String get backendSettingTitle;

  /// Backend status text with Supabase host
  ///
  /// In en, this message translates to:
  /// **'Supabase configured: {host}'**
  String backendConfigured(String host);

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get signInWithApple;

  /// No description provided for @authErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not complete sign in. Try again.'**
  String get authErrorMessage;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @viewMomentDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewMomentDetails;

  /// No description provided for @momentDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Moment details'**
  String get momentDetailsTitle;

  /// No description provided for @momentDetailsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load this moment.'**
  String get momentDetailsLoadError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @momentsLoadRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Moments did not load'**
  String get momentsLoadRetryTitle;

  /// No description provided for @momentDetailsLoadRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Moment did not load'**
  String get momentDetailsLoadRetryTitle;

  /// No description provided for @commentsLoadRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments did not load'**
  String get commentsLoadRetryTitle;

  /// No description provided for @networkOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline.'**
  String get networkOfflineMessage;

  /// No description provided for @networkTimeoutMessage.
  ///
  /// In en, this message translates to:
  /// **'The network is taking too long.'**
  String get networkTimeoutMessage;

  /// No description provided for @genericFailureMessage.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get genericFailureMessage;

  /// No description provided for @createMomentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create moment'**
  String get createMomentTooltip;

  /// No description provided for @createMomentTitle.
  ///
  /// In en, this message translates to:
  /// **'Create moment'**
  String get createMomentTitle;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @publishMoment.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publishMoment;

  /// No description provided for @createMomentUploadingMedia.
  ///
  /// In en, this message translates to:
  /// **'Uploading media...'**
  String get createMomentUploadingMedia;

  /// No description provided for @createMomentSavingMoment.
  ///
  /// In en, this message translates to:
  /// **'Saving moment...'**
  String get createMomentSavingMoment;

  /// No description provided for @createMomentSaved.
  ///
  /// In en, this message translates to:
  /// **'Moment published.'**
  String get createMomentSaved;

  /// No description provided for @createMomentSaveError.
  ///
  /// In en, this message translates to:
  /// **'Could not publish this moment.'**
  String get createMomentSaveError;

  /// No description provided for @createMomentMediaEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or video'**
  String get createMomentMediaEmpty;

  /// No description provided for @createMomentMediaError.
  ///
  /// In en, this message translates to:
  /// **'Could not show this media'**
  String get createMomentMediaError;

  /// No description provided for @removeMedia.
  ///
  /// In en, this message translates to:
  /// **'Remove media'**
  String get removeMedia;

  /// No description provided for @pickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Pick photo'**
  String get pickPhoto;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @pickVideo.
  ///
  /// In en, this message translates to:
  /// **'Pick video'**
  String get pickVideo;

  /// No description provided for @recordVideo.
  ///
  /// In en, this message translates to:
  /// **'Record video'**
  String get recordVideo;

  /// No description provided for @createMomentTextLabel.
  ///
  /// In en, this message translates to:
  /// **'What happened here?'**
  String get createMomentTextLabel;

  /// No description provided for @createMomentEmotionLabel.
  ///
  /// In en, this message translates to:
  /// **'Emotion'**
  String get createMomentEmotionLabel;

  /// No description provided for @createMomentTextRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a short description.'**
  String get createMomentTextRequired;

  /// No description provided for @createMomentDraftInvalid.
  ///
  /// In en, this message translates to:
  /// **'Add media and a description first.'**
  String get createMomentDraftInvalid;

  /// No description provided for @createMomentDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved.'**
  String get createMomentDraftSaved;

  /// No description provided for @createMomentMediaPickError.
  ///
  /// In en, this message translates to:
  /// **'Could not pick media.'**
  String get createMomentMediaPickError;

  /// No description provided for @likeMoment.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get likeMoment;

  /// No description provided for @unlikeMoment.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get unlikeMoment;

  /// No description provided for @momentLikeError.
  ///
  /// In en, this message translates to:
  /// **'Could not update like.'**
  String get momentLikeError;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @commentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get commentsEmpty;

  /// No description provided for @commentInputHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment'**
  String get commentInputHint;

  /// No description provided for @replyInputHint.
  ///
  /// In en, this message translates to:
  /// **'Write a reply'**
  String get replyInputHint;

  /// No description provided for @sendComment.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendComment;

  /// No description provided for @replyToComment.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyToComment;

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @commentSendError.
  ///
  /// In en, this message translates to:
  /// **'Could not send comment.'**
  String get commentSendError;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsEnabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get notificationsEnabled;

  /// No description provided for @notificationsDisabled.
  ///
  /// In en, this message translates to:
  /// **'Notifications disabled'**
  String get notificationsDisabled;

  /// No description provided for @notificationsAsk.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get notificationsAsk;

  /// No description provided for @notificationsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked in system settings.'**
  String get notificationsPermissionDenied;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
