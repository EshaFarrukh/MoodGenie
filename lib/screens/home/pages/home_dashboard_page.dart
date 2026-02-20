import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:moodgenie/screens/mood/mood_analytics_screen.dart';
import 'package:moodgenie/screens/mood/mood_log_screen.dart';
import 'package:moodgenie/screens/therapist/therapist_list_screen.dart';
import 'package:moodgenie/screens/home/widgets/glass_card.dart';
import 'package:moodgenie/screens/home/widgets/mood_chip.dart';
import 'package:moodgenie/screens/home/widgets/mood_bar.dart';
import 'package:moodgenie/screens/home/widgets/circular_score_painter.dart';
import 'package:moodgenie/screens/home/widgets/mood_count_row.dart';
import 'package:moodgenie/src/services/mood_repository.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final emailName = (user?.email ?? 'friend').split('@').first;
    final displayName = emailName.isNotEmpty
        ? emailName[0].toUpperCase() + emailName.substring(1)
        : 'friend';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Good morning, $displayName,',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D2545),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFFFD39B),
                    child: Icon(
                      Icons.person,
                      size: 26,
                      color: Color(0xFF5B3C61),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'How are you feeling today?\nLet MoodGenie check in with you.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6D6689),
                  height: 1.4,
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Quick Mood Check
          GlassCard(
            gradientColors: const [
              Color(0xFFFFF5EA),
              Color(0xFFFFEFE3),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '😊 Quick Mood Check',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE5723F),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Log your mood in under 10 seconds.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A7F92),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: const [
                            MoodChip(label: 'Low', emoji: '😞'),
                            SizedBox(width: 8),
                            MoodChip(label: 'Okay', emoji: '🙂'),
                            SizedBox(width: 8),
                            MoodChip(label: 'Good', emoji: '😊'),
                            SizedBox(width: 8),
                            MoodChip(label: 'Great', emoji: '😄'),
                            SizedBox(width: 8),
                            MoodChip(label: 'Amazing', emoji: '🤩'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8E58),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const MoodLogScreen()),
                          );
                          _refreshData();
                        },
                        child: const Text(
                          'Log Mood',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Mood Summary with real data
          FutureBuilder<Map<String, dynamic>>(
            future: _moodSummaryFuture, // Use the cached future
            builder: (context, snapshot) {
              // Default values
              final data = snapshot.data ?? {
                'bars': List.filled(7, 30.0),
                'average': 0.0,
                'counts': <String, int>{},
                'total': 0,
              };
              
              final bars = data['bars'] as List<dynamic>;
              final average = (data['average'] as double);
              final moodCounts = data['counts'] as Map<String, int>;
              
              // Calculate mood breakdown
              final greatCount = moodCounts['great'] ?? moodCounts['happy'] ?? 0;
              final okayCount = moodCounts['okay'] ?? moodCounts['neutral'] ?? 0;
              final lowCount = moodCounts['low'] ?? moodCounts['sad'] ?? 0;

              return GlassCard(
                gradientColors: const [
                  Color(0xFFFFFFFF),
                  Color(0xFFFDF5FF),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Text(
                              '📊',
                              style: TextStyle(fontSize: 22),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Mood Summary',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2D2545),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        // Last 7 Days badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Last 7 Days',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Show loading or data
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else ...[
                      // Circular score and mood breakdown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left side - Circular Score
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer ring
                                SizedBox(
                                  width: 130,
                                  height: 130,
                                  child: CustomPaint(
                                    painter: CircularScorePainter(
                                      score: average,
                                      maxScore: 10.0,
                                    ),
                                  ),
                                ),
                                // Score text in center
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      average > 0 ? average.toStringAsFixed(1) : '—',
                                      style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF2D2545),
                                        height: 1,
                                        letterSpacing: -1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Score',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF9B8FD8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Right side - Mood breakdown
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
                                const SizedBox(height: 10),
                                MoodCountRow(
                                  emoji: '😐',
                                  label: 'Okay',
                                  count: okayCount,
                                  color: const Color(0xFF9B8FD8),
                                ),
                                const SizedBox(height: 10),
                                MoodCountRow(
                                  emoji: '😔',
                                  label: 'Low',
                                  count: lowCount,
                                  color: const Color(0xFFB3A4E8),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // 7 Day Trend section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            '7 Day Trend',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF36315A),
                            ),
                          ),
                          Text(
                            'Mon - Sun',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9B8FD8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bar chart with real data
                      Container(
                        height: 100,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.06),
                              AppColors.primaryDeep.withOpacity(0.03),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE5DEFF).withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: bars.isEmpty
                            ? const Center(
                                child: Text(
                                  'No mood data yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9B8FD8),
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: bars.map((height) {
                                  final index = bars.indexOf(height);
                                  final colors = [
                                    const Color(0xFF9B8FD8),
                                    AppColors.primary,
                                    const Color(0xFF9B8FD8),
                                    const Color(0xFF7B6FD8),
                                    AppColors.primary,
                                    AppColors.primaryDeep,
                                    const Color(0xFF7B6FD8),
                                  ];
                                  return MoodBar(
                                    height: (height as double).clamp(20.0, 70.0),
                                    color: colors[index % colors.length],
                                  );
                                }).toList(),
                              ),
                      ),

                      const SizedBox(height: 10),

                      // View Full Report button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MoodAnalyticsScreen()),
                            );
                            _refreshData(); // Refresh data using the new method
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryDeep,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            shadowColor: AppColors.primaryDeep.withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                'View Full Report',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          // Bottom row: Talk to MoodGenie & Therapist
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  gradientColors: const [
                    Color(0xFFF4EFFF),
                    Color(0xFFEDE6FF),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Talk to MoodGenie',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF37325C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Chat with your AI support coach.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF847C9D),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: widget.onNavigateToChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B5CFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Start Chat', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  gradientColors: const [
                    Color(0xFFFFF1E5),
                    Color(0xFFFFF7EE),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Therapist',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE5723F),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Connect with mental health professionals.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A7F92),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TherapistListScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8E58),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: const Text('Find Therapist', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
