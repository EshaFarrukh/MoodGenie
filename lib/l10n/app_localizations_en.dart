// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MoodGenie';

  @override
  String get splashTagline => 'Your AI Mental Wellness Companion';

  @override
  String get splashLoadingLabel => 'Loading MoodGenie';

  @override
  String get navigationBarLabel => 'Primary navigation';

  @override
  String get navHome => 'Home';

  @override
  String get navMood => 'Mood';

  @override
  String get navChat => 'Chat';

  @override
  String get navTherapist => 'Therapist';

  @override
  String get navPatients => 'Patients';

  @override
  String get navSchedule => 'Schedule';

  @override
  String get navProfile => 'Profile';

  @override
  String navTabTooltip(String tab) {
    return '$tab tab';
  }

  @override
  String get navCurrentTabHint => 'Current tab';

  @override
  String navSwitchTabHint(String tab) {
    return 'Switch to the $tab tab';
  }

  @override
  String get therapistDashboardTitle => 'Clinician Dashboard';

  @override
  String get signOut => 'Sign out';

  @override
  String get termsPrivacyTitle => 'Terms & Privacy';

  @override
  String get termsBackButtonTooltip => 'Back';

  @override
  String get termsOfServiceTitle => 'Terms of Service';

  @override
  String get termsOfServiceSubtitle => 'Last updated: February 2026';

  @override
  String get termsOfServiceContent =>
      'By using MoodGenie, you agree to the following terms:\n\n1. **Account**: You must be 13+ to use MoodGenie. You are responsible for maintaining the security of your account credentials.\n\n2. **Usage**: MoodGenie is a wellness companion, not a medical service. It does not provide medical diagnoses, treatment, or professional therapy. Always consult a licensed professional for mental health concerns.\n\n3. **Content**: You retain ownership of all content you create (mood entries, notes, feedback). We do not sell or share your personal data with third parties.\n\n4. **Availability**: We strive to keep MoodGenie available 24/7, but we do not guarantee uninterrupted access. We may modify or discontinue features with notice.\n\n5. **Conduct**: You agree not to misuse the service, attempt to gain unauthorized access, or use the app for any unlawful purpose.';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle => 'Your privacy matters to us';

  @override
  String get privacyPolicyContent =>
      '**Data We Collect**\n• Account information (email, display name)\n• Mood entries (mood, intensity, notes, timestamps)\n• Chat messages with the AI companion\n• Appointment bookings and therapist chat records\n• Therapist-sharing consent choices\n\n**How We Use Your Data**\n• To provide and improve the MoodGenie experience\n• To display your mood trends and analytics\n• To facilitate AI chat conversations\n• To enable therapist appointment booking, therapist messaging, and session coordination\n\n**Data Storage**\nYour data is stored securely using Google Firebase with encryption at rest and in transit. We follow industry-standard security practices.\n\n**Data Sharing**\nWe do NOT sell or rent your personal data. Your mood data stays private by default. If you explicitly choose to share it with a therapist as part of booking or care coordination, that therapist may be able to view the shared history needed for your care.\n\n**Data Retention**\nYour data is retained while your account remains active. You can request a secure data export package from Profile settings and request full account deletion from the app.\n\n**Your Rights**\n• Access: View the personal data available in the app\n• Export: Request a secure export package of your in-app data (Profile → Export My Data)\n• Delete: Permanently remove your account and associated in-app records (Profile → Delete Account)\n• Modify: Update your profile information at any time';

  @override
  String get aiDisclaimerTitle => 'AI Disclaimer';

  @override
  String get aiDisclaimerSubtitle => 'Important information about our AI';

  @override
  String get aiDisclaimerContent =>
      'MoodGenie\'s AI chat feature is designed to provide emotional support and general wellness guidance.\n\n**The AI is NOT:**\n• A licensed therapist or counselor\n• A medical professional\n• A substitute for professional mental health care\n\n**If you are in crisis:**\nPlease contact emergency services (911) or the National Suicide Prevention Lifeline (988) immediately.\n\nWe encourage you to use MoodGenie alongside professional support, not as a replacement for it.';

  @override
  String get termsSupportFooter =>
      'Questions? Reach out via Send Feedback in Settings.';

  @override
  String get aiChatTitle => 'MoodGenie AI';

  @override
  String get aiStatusConnecting => 'Connecting…';

  @override
  String get aiStatusConnected => 'AI Connected';

  @override
  String get aiStatusDegraded => 'AI Degraded';

  @override
  String get aiStatusFallback => 'Fallback support mode';

  @override
  String get aiStatusCrisis => 'Crisis support mode';

  @override
  String aiStatusSemanticLabel(String status) {
    return 'AI status: $status';
  }

  @override
  String get chatOptionsTooltip => 'Chat options';

  @override
  String get retryAiConnection => 'Retry AI connection';

  @override
  String get clearConversation => 'Clear conversation';

  @override
  String get aiDegradedBanner =>
      'The AI service is reachable but currently degraded. Replies may fall back to built-in support guidance until the service recovers.';

  @override
  String get aiFallbackBanner =>
      'The live AI service is unavailable right now. Responses are coming from the app fallback mode and may be less personalized.';

  @override
  String get aiCrisisBanner =>
      'MoodGenie switched into crisis support mode for this conversation and is prioritizing emergency guidance over normal AI replies.';
}
