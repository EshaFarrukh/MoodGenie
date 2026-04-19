import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('ur'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MoodGenie'**
  String get appTitle;

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'Your AI Mental Wellness Companion'**
  String get splashTagline;

  /// No description provided for @splashLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading MoodGenie'**
  String get splashLoadingLabel;

  /// No description provided for @navigationBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary navigation'**
  String get navigationBarLabel;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get navMood;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navTherapist.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get navTherapist;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navTabTooltip.
  ///
  /// In en, this message translates to:
  /// **'{tab} tab'**
  String navTabTooltip(String tab);

  /// No description provided for @navCurrentTabHint.
  ///
  /// In en, this message translates to:
  /// **'Current tab'**
  String get navCurrentTabHint;

  /// No description provided for @navSwitchTabHint.
  ///
  /// In en, this message translates to:
  /// **'Switch to the {tab} tab'**
  String navSwitchTabHint(String tab);

  /// No description provided for @therapistDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinician Dashboard'**
  String get therapistDashboardTitle;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @termsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms & Privacy'**
  String get termsPrivacyTitle;

  /// No description provided for @termsBackButtonTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get termsBackButtonTooltip;

  /// No description provided for @termsOfServiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceTitle;

  /// No description provided for @termsOfServiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Last updated: February 2026'**
  String get termsOfServiceSubtitle;

  /// No description provided for @termsOfServiceContent.
  ///
  /// In en, this message translates to:
  /// **'By using MoodGenie, you agree to the following terms:\n\n1. **Account**: You must be 13+ to use MoodGenie. You are responsible for maintaining the security of your account credentials.\n\n2. **Usage**: MoodGenie is a wellness companion, not a medical service. It does not provide medical diagnoses, treatment, or professional therapy. Always consult a licensed professional for mental health concerns.\n\n3. **Content**: You retain ownership of all content you create (mood entries, notes, feedback). We do not sell or share your personal data with third parties.\n\n4. **Availability**: We strive to keep MoodGenie available 24/7, but we do not guarantee uninterrupted access. We may modify or discontinue features with notice.\n\n5. **Conduct**: You agree not to misuse the service, attempt to gain unauthorized access, or use the app for any unlawful purpose.'**
  String get termsOfServiceContent;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your privacy matters to us'**
  String get privacyPolicySubtitle;

  /// No description provided for @privacyPolicyContent.
  ///
  /// In en, this message translates to:
  /// **'**Data We Collect**\n• Account information (email, display name)\n• Mood entries (mood, intensity, notes, timestamps)\n• Chat messages with the AI companion\n• Appointment bookings and therapist chat records\n• Therapist-sharing consent choices\n\n**How We Use Your Data**\n• To provide and improve the MoodGenie experience\n• To display your mood trends and analytics\n• To facilitate AI chat conversations\n• To enable therapist appointment booking, therapist messaging, and session coordination\n\n**Data Storage**\nYour data is stored securely using Google Firebase with encryption at rest and in transit. We follow industry-standard security practices.\n\n**Data Sharing**\nWe do NOT sell or rent your personal data. Your mood data stays private by default. If you explicitly choose to share it with a therapist as part of booking or care coordination, that therapist may be able to view the shared history needed for your care.\n\n**Data Retention**\nYour data is retained while your account remains active. You can request a secure data export package from Profile settings and request full account deletion from the app.\n\n**Your Rights**\n• Access: View the personal data available in the app\n• Export: Request a secure export package of your in-app data (Profile → Export My Data)\n• Delete: Permanently remove your account and associated in-app records (Profile → Delete Account)\n• Modify: Update your profile information at any time'**
  String get privacyPolicyContent;

  /// No description provided for @aiDisclaimerTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Disclaimer'**
  String get aiDisclaimerTitle;

  /// No description provided for @aiDisclaimerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Important information about our AI'**
  String get aiDisclaimerSubtitle;

  /// No description provided for @aiDisclaimerContent.
  ///
  /// In en, this message translates to:
  /// **'MoodGenie\'s AI chat feature is designed to provide emotional support and general wellness guidance.\n\n**The AI is NOT:**\n• A licensed therapist or counselor\n• A medical professional\n• A substitute for professional mental health care\n\n**If you are in crisis:**\nPlease contact emergency services (911) or the National Suicide Prevention Lifeline (988) immediately.\n\nWe encourage you to use MoodGenie alongside professional support, not as a replacement for it.'**
  String get aiDisclaimerContent;

  /// No description provided for @termsSupportFooter.
  ///
  /// In en, this message translates to:
  /// **'Questions? Reach out via Send Feedback in Settings.'**
  String get termsSupportFooter;

  /// No description provided for @aiChatTitle.
  ///
  /// In en, this message translates to:
  /// **'MoodGenie AI'**
  String get aiChatTitle;

  /// No description provided for @aiStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get aiStatusConnecting;

  /// No description provided for @aiStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'AI Connected'**
  String get aiStatusConnected;

  /// No description provided for @aiStatusDegraded.
  ///
  /// In en, this message translates to:
  /// **'AI Degraded'**
  String get aiStatusDegraded;

  /// No description provided for @aiStatusFallback.
  ///
  /// In en, this message translates to:
  /// **'Fallback support mode'**
  String get aiStatusFallback;

  /// No description provided for @aiStatusCrisis.
  ///
  /// In en, this message translates to:
  /// **'Crisis support mode'**
  String get aiStatusCrisis;

  /// No description provided for @aiStatusSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'AI status: {status}'**
  String aiStatusSemanticLabel(String status);

  /// No description provided for @chatOptionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chat options'**
  String get chatOptionsTooltip;

  /// No description provided for @retryAiConnection.
  ///
  /// In en, this message translates to:
  /// **'Retry AI connection'**
  String get retryAiConnection;

  /// No description provided for @clearConversation.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get clearConversation;

  /// No description provided for @aiDegradedBanner.
  ///
  /// In en, this message translates to:
  /// **'The AI service is reachable but currently degraded. Replies may fall back to built-in support guidance until the service recovers.'**
  String get aiDegradedBanner;

  /// No description provided for @aiFallbackBanner.
  ///
  /// In en, this message translates to:
  /// **'The live AI service is unavailable right now. Responses are coming from the app fallback mode and may be less personalized.'**
  String get aiFallbackBanner;

  /// No description provided for @aiCrisisBanner.
  ///
  /// In en, this message translates to:
  /// **'MoodGenie switched into crisis support mode for this conversation and is prioritizing emergency guidance over normal AI replies.'**
  String get aiCrisisBanner;
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
      <String>['en', 'ur'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
