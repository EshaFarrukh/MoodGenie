import 'package:flutter/material.dart';
import 'package:moodgenie/screens/chat/chat_screen.dart';
import 'package:moodgenie/screens/mood/mood_analytics_screen.dart';
import 'package:moodgenie/screens/mood/mood_log_screen.dart';
import 'package:moodgenie/screens/mood/mood_history_screen.dart';
import 'package:moodgenie/screens/home/widgets/glass_card.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

/// ─── Mood Tab ─────────────────────────────────────────────────────

class MoodTabPage extends StatelessWidget {
  const MoodTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            '🎭 Your Mood',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.headingDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track, reflect, and understand your emotions.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.bodyMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),

          // Log Today's Mood — hero card
          GlassCard(
            gradientColors: const [Color(0xFFFFF5EA), Color(0xFFFFEFE3)],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB06A), Color(0xFFFF7F72)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                        boxShadow: AppShadows.glow(AppColors.accentWarm),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log Today\'s Mood',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.headingDark,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Capture how you\'re feeling right now',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.captionLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MoodLogScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentWarm,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Log Mood Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Two-column: Analytics / History
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.insights_rounded,
                  iconGradient: const [AppColors.purple, AppColors.purpleDeep],
                  title: 'Analytics',
                  subtitle: 'Trends & patterns',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MoodAnalyticsScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.calendar_month_rounded,
                  iconGradient: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
                  title: 'History',
                  subtitle: 'Day-by-day log',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MoodHistoryScreen()),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Tip Card
          GlassCard(
            gradientColors: const [Color(0xFFF4EFFF), Color(0xFFEDE6FF)],
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.purpleDeep.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.tips_and_updates_rounded,
                    color: AppColors.purpleDeep,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Tip',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Logging your mood consistently helps you identify emotional triggers and build self-awareness over time.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.bodyMuted,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
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
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: const [Color(0xFFFFFFFF), Color(0xFFFDF5FF)],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: iconGradient),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.glow(iconGradient.last),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.headingDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.captionLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'View',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconGradient.last,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16, color: iconGradient.last),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Chat Tab ─────────────────────────────────────────────────────

class ChatTabPage extends StatelessWidget {
  const ChatTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ChatScreen();
  }
}
