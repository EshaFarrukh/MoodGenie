import 'package:flutter/material.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import '../../../src/theme/app_theme.dart';

class TermsPrivacyPage extends StatelessWidget {
  const TermsPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: Stack(
        children: [
          // Background
          const Positioned.fill(child: AppBackground()),
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
                        tooltip: l10n.termsBackButtonTooltip,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.headingDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.termsPrivacyTitle,
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
                        l10n.termsOfServiceTitle,
                        Icons.description_outlined,
                        l10n.termsOfServiceSubtitle,
                        l10n.termsOfServiceContent,
                      ),
                      const SizedBox(height: 20),
                      _buildSection(
                        l10n.privacyPolicyTitle,
                        Icons.shield_outlined,
                        l10n.privacyPolicySubtitle,
                        l10n.privacyPolicyContent,
                      ),
                      const SizedBox(height: 20),
                      _buildSection(
                        l10n.aiDisclaimerTitle,
                        Icons.smart_toy_outlined,
                        l10n.aiDisclaimerSubtitle,
                        l10n.aiDisclaimerContent,
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          l10n.termsSupportFooter,
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

  Widget _buildSection(
    String title,
    IconData icon,
    String subtitle,
    String content,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
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
                  child: Semantics(
                    header: true,
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
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: AppColors.primaryFaint.withValues(alpha: 0.5),
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
