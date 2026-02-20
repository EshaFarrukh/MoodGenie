import 'package:flutter/material.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import '../../../src/theme/app_theme.dart';

class TermsPrivacyPage extends StatelessWidget {
  const TermsPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: Stack(
        children: [
          // Background
          const Positioned.fill(
            child: AppBackground(),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.headingDark),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Terms & Privacy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.headingDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _buildSection(
                        'Terms of Service',
                        Icons.description_outlined,
                        'Last updated: February 2026',
                        '''By using MoodGenie, you agree to the following terms:

1. **Account**: You must be 13+ to use MoodGenie. You are responsible for maintaining the security of your account credentials.

2. **Usage**: MoodGenie is a wellness companion, not a medical service. It does not provide medical diagnoses, treatment, or professional therapy. Always consult a licensed professional for mental health concerns.

3. **Content**: You retain ownership of all content you create (mood entries, notes, feedback). We do not sell or share your personal data with third parties.

4. **Availability**: We strive to keep MoodGenie available 24/7, but we do not guarantee uninterrupted access. We may modify or discontinue features with notice.

5. **Conduct**: You agree not to misuse the service, attempt to gain unauthorized access, or use the app for any unlawful purpose.''',
                      ),
                      const SizedBox(height: 20),
                      _buildSection(
                        'Privacy Policy',
                        Icons.shield_outlined,
                        'Your privacy matters to us',
                        '''**Data We Collect**
• Account information (email, display name)
• Mood entries (mood, intensity, notes, timestamps)
• Chat messages with the AI companion
• Appointment bookings

**How We Use Your Data**
• To provide and improve the MoodGenie experience
• To display your mood trends and analytics
• To facilitate AI chat conversations
• To enable therapist appointment booking

**Data Storage**
Your data is stored securely using Google Firebase with encryption at rest and in transit. We follow industry-standard security practices.

**Data Sharing**
We do NOT sell, rent, or share your personal data with third parties. Your mood data is visible only to you.

**Data Retention**
Your data is retained as long as your account is active. You can export or delete your data at any time from Profile settings.

**Your Rights**
• Access: View all your data in the app
• Export: Download your data as CSV (Profile → Export My Data)
• Delete: Permanently remove all data (Profile → Delete Account)
• Modify: Update your profile information at any time''',
                      ),
                      const SizedBox(height: 20),
                      _buildSection(
                        'AI Disclaimer',
                        Icons.smart_toy_outlined,
                        'Important information about our AI',
                        '''MoodGenie's AI chat feature is designed to provide emotional support and general wellness guidance.

**The AI is NOT:**
• A licensed therapist or counselor
• A medical professional
• A substitute for professional mental health care

**If you are in crisis:**
Please contact emergency services (911) or the National Suicide Prevention Lifeline (988) immediately.

We encourage you to use MoodGenie alongside professional support, not as a replacement for it.''',
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'Questions? Reach out via Send Feedback in Settings.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.captionLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, String subtitle, String content) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadows.soft(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.captionLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: AppColors.primaryFaint.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.bodyMuted,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
