import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:moodgenie/screens/mood/mood_analytics_screen.dart';
import 'package:moodgenie/screens/mood/mood_log_screen.dart';
import 'package:moodgenie/screens/therapist/my_therapy_requests_screen.dart';
import 'package:moodgenie/screens/therapist/therapist_list_screen.dart';
import 'package:moodgenie/screens/notifications/widgets/notification_bell_button.dart';
import 'package:moodgenie/screens/home/widgets/shared_bottom_navigation.dart';
import 'package:moodgenie/screens/home/widgets/circular_score_painter.dart';
import 'package:moodgenie/screens/home/widgets/mood_count_row.dart';
import 'package:moodgenie/src/services/mood_repository.dart';
import 'package:moodgenie/src/theme/app_theme.dart';
import 'package:moodgenie/screens/home/pages/profile_tab_page.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:moodgenie/models/session_model.dart';
import 'package:intl/intl.dart';

class HomeDashboardPage extends StatefulWidget {
  final VoidCallback onNavigateToChat;

  const HomeDashboardPage({required this.onNavigateToChat, super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  late Future<Map<String, dynamic>> _moodSummaryFuture;
  final MoodRepository _moodRepository = MoodRepository();

  @override
  void initState() {
    super.initState();
    _moodSummaryFuture = _loadMoodSummary();
  }

  Future<Map<String, dynamic>> _loadMoodSummary() async {
    return _moodRepository.getMoodSummary();
  }

  void _refreshData() {
    setState(() {
      _moodSummaryFuture = _loadMoodSummary();
    });
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final bottomSpacing = SharedBottomNavigation.reservedHeight(context);
    final user = FirebaseAuth.instance.currentUser;
    final emailName = (user?.email ?? 'friend').split('@').first;
    final displayName = emailName.isNotEmpty
        ? emailName[0].toUpperCase() + emailName.substring(1)
        : 'friend';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Greeting Header ───
          _buildGreetingHeader(displayName),

          const SizedBox(height: 22),

          // ─── Quick Mood Check ───
          _buildQuickMoodCheck(),

          const SizedBox(height: 16),

          // ─── Mood Summary ───
          _buildMoodSummary(),

          const SizedBox(height: 16),

          // ─── Upcoming Therapy Session ───
          if (user != null) _buildUpcomingTherapy(user.uid),

          const SizedBox(height: 16),

          // ─── Action Cards Row ───
          _buildActionCards(),

          const SizedBox(height: 16),

          // ─── Daily Wellness Tip ───
          _buildDailyTip(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GREETING HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGreetingHeader(String displayName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getTimeGreeting()},',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$displayName 👋',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF002B5B),
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('EEEE, MMM d').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              const NotificationBellButton(),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _ProfileWrapperScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFE0F2FE),
                    child: Icon(
                      Icons.person_rounded,
                      size: 28,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QUICK MOOD CHECK
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQuickMoodCheck() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.emoji_emotions_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Mood Check',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF002B5B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'How are you feeling right now?',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),

          // Mood emoji row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMoodEmoji('😞', 'Low'),
              _buildMoodEmoji('🙂', 'Okay'),
              _buildMoodEmoji('😊', 'Good'),
              _buildMoodEmoji('😄', 'Great'),
              _buildMoodEmoji('🤩', 'Amazing'),
            ],
          ),

          const SizedBox(height: 16),

          // Log Mood button — full width gradient
          SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDeep],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MoodLogScreen()),
                  );
                  _refreshData();
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Log Your Mood',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodEmoji(String emoji, String label) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const MoodLogScreen()));
        _refreshData();
      },
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.12),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MOOD SUMMARY
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMoodSummary() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _moodSummaryFuture,
      builder: (context, snapshot) {
        final data =
            snapshot.data ??
            {
              'bars': List.filled(7, 30.0),
              'average': 0.0,
              'counts': <String, int>{},
              'total': 0,
            };

        final bars = data['bars'] as List<dynamic>;
        final average = (data['average'] as double);
        final moodCounts = data['counts'] as Map<String, int>;
        final trendValues = List<double>.generate(7, (index) {
          if (index >= bars.length) {
            return 0;
          }
          final raw = (bars[index] as num?)?.toDouble() ?? 20;
          return ((raw - 20) / 50).clamp(0.0, 1.0);
        });
        final peakTrend =
            trendValues.isEmpty
                ? 0.0
                : trendValues.reduce((left, right) => left > right ? left : right);
        final moodLabel =
            average >= 7.5
                ? 'Strong'
                : average >= 5
                ? 'Steady'
                : average > 0
                ? 'Low'
                : 'No logs';

        final greatCount = moodCounts['great'] ?? moodCounts['happy'] ?? 0;
        final okayCount = moodCounts['okay'] ?? moodCounts['neutral'] ?? 0;
        final lowCount = moodCounts['low'] ?? moodCounts['sad'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.95),
                Colors.white.withValues(alpha: 0.88),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDeep],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Mood Summary',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF002B5B),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Last 7 Days',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Loading or content
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else ...[
                // Score + Mood breakdown
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circular Score
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CustomPaint(
                              painter: CircularScorePainter(
                                score: average,
                                maxScore: 10.0,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                average > 0 ? average.toStringAsFixed(1) : '—',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF002B5B),
                                  height: 1,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Score',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.7,
                                  ),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Mood breakdown
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MoodCountRow(
                            emoji: '😊',
                            label: 'Great',
                            count: greatCount,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          MoodCountRow(
                            emoji: '😐',
                            label: 'Okay',
                            count: okayCount,
                            color: AppColors.accentCyan,
                          ),
                          const SizedBox(height: 8),
                          MoodCountRow(
                            emoji: '😔',
                            label: 'Low',
                            count: lowCount,
                            color: AppColors.captionLight,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

	                // 7 Day Trend
	                Row(
	                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
	                  children: [
	                    const Text(
	                      '7-Day Trend',
	                      style: TextStyle(
	                        fontSize: 14,
	                        fontWeight: FontWeight.w800,
	                        color: Color(0xFF002B5B),
	                      ),
	                    ),
	                    Container(
	                      padding: const EdgeInsets.symmetric(
	                        horizontal: 10,
	                        vertical: 6,
	                      ),
	                      decoration: BoxDecoration(
	                        color: AppColors.primaryLight.withValues(alpha: 0.75),
	                        borderRadius: BorderRadius.circular(999),
	                      ),
	                      child: Text(
	                        average > 0
	                            ? '${average.toStringAsFixed(1)} • $moodLabel'
	                            : 'Mon – Sun',
	                        style: TextStyle(
	                          fontSize: 11,
	                          fontWeight: FontWeight.w700,
	                          color: AppColors.primaryDeep.withValues(alpha: 0.88),
	                        ),
	                      ),
	                    ),
	                  ],
	                ),
	                const SizedBox(height: 12),

	                Container(
	                  height: 150,
	                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
	                  decoration: BoxDecoration(
	                    gradient: LinearGradient(
	                      colors: [
	                        Colors.white.withValues(alpha: 0.86),
	                        AppColors.primaryLight.withValues(alpha: 0.48),
	                      ],
	                      begin: Alignment.topCenter,
	                      end: Alignment.bottomCenter,
	                    ),
	                    borderRadius: BorderRadius.circular(18),
	                    border: Border.all(
	                      color: AppColors.primary.withValues(alpha: 0.12),
	                      width: 1,
	                    ),
	                  ),
	                  child: bars.isEmpty
	                      ? Center(
	                          child: Text(
	                            'No mood data yet',
	                            style: TextStyle(
	                              fontSize: 12,
	                              color: AppColors.textSecondary.withValues(
	                                alpha: 0.6,
	                              ),
	                            ),
	                          ),
	                        )
	                      : Stack(
	                          children: [
	                            Positioned.fill(
	                              child: Padding(
	                                padding: const EdgeInsets.only(
	                                  top: 6,
	                                  bottom: 26,
	                                ),
	                                child: Column(
	                                  mainAxisAlignment:
	                                      MainAxisAlignment.spaceBetween,
	                                  children: List.generate(
	                                    4,
	                                    (_) => Container(
	                                      height: 1,
	                                      color: AppColors.primary.withValues(
	                                        alpha: 0.08,
	                                      ),
	                                    ),
	                                  ),
	                                ),
	                              ),
	                            ),
	                            Row(
	                              crossAxisAlignment: CrossAxisAlignment.end,
	                              children: List.generate(7, (index) {
	                                const dayLabels = [
	                                  'M',
	                                  'T',
	                                  'W',
	                                  'T',
	                                  'F',
	                                  'S',
	                                  'S',
	                                ];
	                                final barColors = [
	                                  AppColors.accentCyan,
	                                  AppColors.primary,
	                                  AppColors.primaryMid,
	                                  AppColors.primaryDeep,
	                                  AppColors.primary,
	                                  AppColors.accentCyan,
	                                  AppColors.primaryMid,
	                                ];
	                                final normalized = trendValues[index];
	                                final isPeak = normalized > 0 && normalized == peakTrend;
	                                return Expanded(
	                                  child: Column(
	                                    children: [
	                                      Expanded(
	                                        child: Align(
	                                          alignment: Alignment.bottomCenter,
	                                          child: Container(
	                                            width: 24,
	                                            height:
	                                                34 +
	                                                (normalized * 48),
	                                            decoration: BoxDecoration(
	                                              borderRadius:
	                                                  BorderRadius.circular(14),
	                                              gradient: LinearGradient(
	                                                colors: [
	                                                  barColors[index],
	                                                  barColors[index].withValues(
	                                                    alpha: 0.62,
	                                                  ),
	                                                ],
	                                                begin: Alignment.topCenter,
	                                                end: Alignment.bottomCenter,
	                                              ),
	                                              boxShadow: [
	                                                BoxShadow(
	                                                  color: barColors[index]
	                                                      .withValues(alpha: 0.24),
	                                                  blurRadius: isPeak ? 14 : 8,
	                                                  offset: const Offset(0, 6),
	                                                ),
	                                              ],
	                                              border: Border.all(
	                                                color: Colors.white
	                                                    .withValues(alpha: 0.42),
	                                              ),
	                                            ),
	                                          ),
	                                        ),
	                                      ),
	                                      const SizedBox(height: 10),
	                                      Container(
	                                        width: 28,
	                                        height: 24,
	                                        alignment: Alignment.center,
	                                        decoration: BoxDecoration(
	                                          color: Colors.white.withValues(
	                                            alpha: 0.85,
	                                          ),
	                                          borderRadius:
	                                              BorderRadius.circular(10),
	                                        ),
	                                        child: Text(
	                                          dayLabels[index],
	                                          style: TextStyle(
	                                            fontSize: 11,
	                                            fontWeight: FontWeight.w800,
	                                            color: isPeak
	                                                ? AppColors.primaryDeep
	                                                : AppColors.textSecondary
	                                                      .withValues(alpha: 0.8),
	                                          ),
	                                        ),
	                                      ),
	                                    ],
	                                  ),
	                                );
	                              }),
	                            ),
	                          ],
	                        ),
	                ),

	                const SizedBox(height: 14),

                // View Full Report
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MoodAnalyticsScreen(),
                        ),
                      );
                      _refreshData();
                    },
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    label: const Text(
                      'View Full Report',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ACTION CARDS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildActionCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _DashboardActionCard(
              icon: Icons.psychology_rounded,
              iconGradient: const [AppColors.primary, AppColors.primaryDeep],
              title: 'Talk to MoodGenie',
              subtitle: 'Your AI wellness companion',
              primaryLabel: 'Start Chat',
              onPrimaryPressed: widget.onNavigateToChat,
              secondaryPlaceholder: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DashboardActionCard(
              icon: Icons.medical_services_rounded,
              iconGradient: const [AppColors.accentCyan, AppColors.primary],
              title: 'Find a Therapist',
              subtitle: 'Connect with professionals',
              primaryLabel: 'Browse',
              onPrimaryPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TherapistListScreen(),
                  ),
                );
              },
              secondaryLabel: 'My Requests',
              onSecondaryPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyTherapyRequestsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DAILY WELLNESS TIP
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDailyTip() {
    final tips = [
      {
        'icon': Icons.self_improvement_rounded,
        'tip':
            'Take 5 minutes today for a breathing exercise. Your mind will thank you. 🧘',
      },
      {
        'icon': Icons.directions_walk_rounded,
        'tip':
            'A 10-minute walk can boost your mood significantly. Try it today! 🚶',
      },
      {
        'icon': Icons.water_drop_rounded,
        'tip':
            'Stay hydrated! Drinking water regularly helps maintain mental clarity. 💧',
      },
      {
        'icon': Icons.nightlight_round,
        'tip':
            'Quality sleep is key. Try putting your phone away 30 min before bed. 🌙',
      },
      {
        'icon': Icons.favorite_rounded,
        'tip':
            'Write down 3 things you\'re grateful for today. Gratitude shifts perspective. ❤️',
      },
      {
        'icon': Icons.music_note_rounded,
        'tip':
            'Listen to your favorite song. Music has a powerful effect on mood. 🎵',
      },
      {
        'icon': Icons.nature_rounded,
        'tip':
            'Spend some time in nature today. Even a view of greenery helps. 🌿',
      },
    ];
    final todayTip = tips[DateTime.now().day % tips.length];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.8),
            AppColors.primarySoft.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              todayTip['icon'] as IconData,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Wellness Tip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  todayTip['tip'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF002B5B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UPCOMING THERAPY SESSION
  // ═══════════════════════════════════════════════════════════════
  Future<({SessionModel session, String therapistName, int totalRequests})?>
  _loadUpcomingTherapyCard(String userId) async {
    final appointments = FirebaseFirestore.instance.collection('appointments');

    Future<SessionModel?> loadSingle(Query<Map<String, dynamic>> query) async {
      final snapshot = await query.limit(1).get();
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return SessionModel.fromMap(doc.data(), doc.id);
    }

    final now = Timestamp.fromDate(DateTime.now());
    final nextConfirmed = await loadSingle(
      appointments
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: AppointmentStatus.confirmed.value)
          .where('scheduledAt', isGreaterThan: now)
          .orderBy('scheduledAt'),
    );
    final requested = nextConfirmed == null
        ? await loadSingle(
            appointments
                .where('userId', isEqualTo: userId)
                .where('status', isEqualTo: AppointmentStatus.requested.value)
                .orderBy('scheduledAt', descending: true),
          )
        : null;
    final fallback = (nextConfirmed == null && requested == null)
        ? await loadSingle(
            appointments
                .where('userId', isEqualTo: userId)
                .orderBy('scheduledAt', descending: true),
          )
        : null;

    final highlighted = nextConfirmed ?? requested ?? fallback;
    if (highlighted == null) {
      return null;
    }

    final therapistSnapshot = await FirebaseFirestore.instance
        .collection('therapists')
        .doc(highlighted.therapistId)
        .get();
    if (!therapistSnapshot.exists) {
      return null;
    }

    final totalRequests = await appointments
        .where('userId', isEqualTo: userId)
        .count()
        .get()
        .then((snapshot) => snapshot.count ?? 0);

    final therapistName = await _loadTherapistDisplayName(highlighted);
    return (
      session: highlighted,
      therapistName: therapistName,
      totalRequests: totalRequests,
    );
  }

  Future<String> _loadTherapistDisplayName(SessionModel session) async {
    final storedName = session.therapistName?.trim();
    if (storedName != null && storedName.isNotEmpty) {
      return storedName;
    }

    final therapistSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(session.therapistId)
        .get();
    if (!therapistSnapshot.exists) {
      return 'Your Therapist';
    }

    final data = therapistSnapshot.data();
    final resolvedName = data?['name'];
    if (resolvedName is String && resolvedName.trim().isNotEmpty) {
      return resolvedName.trim();
    }
    return 'Your Therapist';
  }

  Widget _buildUpcomingTherapy(String userId) {
    return FutureBuilder<
      ({SessionModel session, String therapistName, int totalRequests})?
    >(
      future: _loadUpcomingTherapyCard(userId),
      builder: (context, snapshot) {
        final card = snapshot.data;
        if (card == null) {
          return const SizedBox.shrink();
        }

        final highlighted = card.session;
        final therapistName = card.therapistName;
        final totalRequests = card.totalRequests;
        final scheduledAt = highlighted.scheduledAt;
        final statusColor = switch (highlighted.status) {
          AppointmentStatus.requested => const Color(0xFFE69F00),
          AppointmentStatus.confirmed => AppColors.accentCyan,
          AppointmentStatus.rejected => Colors.redAccent,
          AppointmentStatus.cancelled => AppColors.textSecondary,
          AppointmentStatus.completed => AppColors.primary,
          AppointmentStatus.noShow => const Color(0xFF8E44AD),
        };
        final leadingIcon = switch (highlighted.status) {
          AppointmentStatus.requested => Icons.schedule_rounded,
          AppointmentStatus.confirmed => Icons.video_call_rounded,
          AppointmentStatus.rejected => Icons.close_rounded,
          AppointmentStatus.cancelled => Icons.block_rounded,
          AppointmentStatus.completed => Icons.check_circle_rounded,
          AppointmentStatus.noShow => Icons.warning_amber_rounded,
        };
        final title = switch (highlighted.status) {
          AppointmentStatus.requested => 'Request Pending',
          AppointmentStatus.confirmed => 'Upcoming Session',
          AppointmentStatus.rejected => 'Request Update',
          AppointmentStatus.cancelled => 'Session Cancelled',
          AppointmentStatus.completed => 'Recent Session',
          AppointmentStatus.noShow => 'Attendance Update',
        };
        final buttonLabel = switch (highlighted.status) {
          AppointmentStatus.requested => 'View Status',
          AppointmentStatus.confirmed => 'Open',
          AppointmentStatus.rejected => 'Review',
          AppointmentStatus.cancelled => 'Review',
          AppointmentStatus.completed => 'History',
          AppointmentStatus.noShow => 'Review',
        };

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MyTherapyRequestsScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withValues(alpha: 0.2),
                        AppColors.primaryLight,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(leadingIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        therapistName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF002B5B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEEE, MMM d · h:mm a').format(scheduledAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalRequests == 1
                            ? '1 therapy request in your history'
                            : '$totalRequests therapy requests in your history',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentCyan, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  const _DashboardActionCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    this.secondaryPlaceholder = false,
  });

  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;
  final bool secondaryPlaceholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.96),
            Colors.white.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: iconGradient),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: iconGradient.last.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF002B5B),
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary.withValues(alpha: 0.74),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: iconGradient),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconGradient.last.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (secondaryLabel != null && onSecondaryPressed != null)
            SizedBox(
              width: double.infinity,
              height: 28,
              child: TextButton(
                onPressed: onSecondaryPressed,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.primary,
                ),
                child: Text(
                  secondaryLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else if (secondaryPlaceholder)
            const SizedBox(height: 28),
        ],
      ),
    );
  }
}

/// Wraps ProfileTabPage in its own route with back navigation.
class _ProfileWrapperScreen extends StatelessWidget {
  const _ProfileWrapperScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Back header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                const Expanded(child: ProfileTabPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
