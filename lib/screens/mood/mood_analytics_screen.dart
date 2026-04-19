// lib/screens/mood/mood_analytics_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:moodgenie/src/theme/app_theme.dart';
import 'package:moodgenie/screens/home/widgets/shared_bottom_navigation.dart';
import 'package:moodgenie/utils/mood_report_generator.dart';
import 'package:share_plus/share_plus.dart';

class MoodAnalyticsScreen extends StatefulWidget {
  const MoodAnalyticsScreen({super.key});

  @override
  State<MoodAnalyticsScreen> createState() => _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends State<MoodAnalyticsScreen> {
  bool _isMonthly = false;

  Future<List<Map<String, dynamic>>> _loadEntries({
    required bool fullHistory,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const [];
    }

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('moods')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: false);

    if (!fullHistory) {
      final timeframeDays = _isMonthly ? 30 : 7;
      final now = DateTime.now();
      final cutoffDate = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: timeframeDays - 1));
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate),
      );
    }

    final snap = await query.get();
    if (snap.docs.isEmpty) {
      return const [];
    }

    final entries = snap.docs.map((d) {
      final data = d.data();

      DateTime date;
      if (data['selectedDate'] != null) {
        date = (data['selectedDate'] as Timestamp).toDate();
      } else if (data['createdAt'] != null) {
        date = (data['createdAt'] as Timestamp).toDate();
      } else if (data['timestamp'] != null) {
        date = (data['timestamp'] as Timestamp).toDate();
      } else {
        date = DateTime.now();
      }

      final intensity = (data['intensity'] as num?)?.toDouble() ?? 5.0;
      final mood = (data['mood'] ?? 'unknown') as String;

      return {
        'date': DateTime(date.year, date.month, date.day),
        'intensity': intensity,
        'mood': mood,
      };
    }).toList();

    entries.sort(
      (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
    );
    return entries;
  }

  Future<Map<String, dynamic>> _loadAnalytics() async {
    final entries = await _loadEntries(fullHistory: false);
    if (entries.isEmpty) return {};

    // Calculate stats for selected timeframe
    final timeframeDays = _isMonthly ? 30 : 7;
    final now = DateTime.now();
    final cutoffDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: timeframeDays - 1));

    final recentEntries = entries
        .where((e) => !(e['date'] as DateTime).isBefore(cutoffDate))
        .toList();

    final avgScore = recentEntries.isEmpty
        ? 0.0
        : recentEntries.fold<double>(
                0,
                (total, e) => total + (e['intensity'] as double),
              ) /
              recentEntries.length;

    // Mood distribution
    final moodCounts = <String, int>{};
    for (final e in recentEntries) {
      final mood = e['mood'] as String;
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }

    // Weekly/Monthly trend chart calculation
    List<Map<String, dynamic>> chartBars = [];
    if (!_isMonthly) {
      // 7 individual days
      for (int i = 6; i >= 0; i--) {
        final dayDate = DateTime(now.year, now.month, now.day - i);
        final dayEntries = recentEntries
            .where(
              (e) =>
                  (e['date'] as DateTime).year == dayDate.year &&
                  (e['date'] as DateTime).month == dayDate.month &&
                  (e['date'] as DateTime).day == dayDate.day,
            )
            .toList();

        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final dayName = days[dayDate.weekday - 1];

        double avgIntensity = 0;
        if (dayEntries.isNotEmpty) {
          avgIntensity =
              dayEntries.fold<double>(
                0,
                (s, e) => s + (e['intensity'] as double),
              ) /
              dayEntries.length;
        }
        chartBars.add({'label': dayName, 'intensity': avgIntensity});
      }
    } else {
      // 4 Weekly averages for the month
      for (int i = 3; i >= 0; i--) {
        final weekStart = DateTime(now.year, now.month, now.day - (i * 7) - 6);
        final weekEnd = DateTime(now.year, now.month, now.day - (i * 7));

        final weekEntries = recentEntries
            .where(
              (e) =>
                  (e['date'] as DateTime).isAfter(
                    weekStart.subtract(const Duration(days: 1)),
                  ) &&
                  (e['date'] as DateTime).isBefore(
                    weekEnd.add(const Duration(days: 1)),
                  ),
            )
            .toList();

        double avgIntensity = 0;
        if (weekEntries.isNotEmpty) {
          avgIntensity =
              weekEntries.fold<double>(
                0,
                (s, e) => s + (e['intensity'] as double),
              ) /
              weekEntries.length;
        }
        chartBars.add({'label': 'W${4 - i}', 'intensity': avgIntensity});
      }
    }

    // Calculate streak - find all unique dates
    final uniqueDates = <DateTime>{};
    for (final entry in entries) {
      uniqueDates.add(entry['date'] as DateTime);
    }

    // Sort dates in descending order
    final sortedDates = uniqueDates.toList()..sort((a, b) => b.compareTo(a));

    // Calculate streak starting from the most recent entry
    var streak = 0;
    if (sortedDates.isNotEmpty) {
      final today = DateTime.now();
      final checkDate = DateTime(today.year, today.month, today.day);

      var currentDate = checkDate;

      for (final date in sortedDates) {
        if (date == currentDate ||
            date == currentDate.subtract(const Duration(days: 1))) {
          streak++;
          currentDate = date.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    return {
      'avgScore': avgScore,
      'entries': recentEntries,
      'chartBars': chartBars,
      'moodCounts': moodCounts,
      'streak': streak,
      'total': recentEntries.length,
      'allEntries': entries, // Full history for PDF
    };
  }

  Future<void> _exportPdf(Map<String, dynamic> data) async {
    try {
      final userName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'MoodGenie User';
      final startDate = DateTime.now().subtract(
        Duration(days: _isMonthly ? 30 : 7),
      );

      final pdfPath = await MoodReportGenerator.generatePdf(
        userName: userName,
        startDate: startDate,
        endDate: DateTime.now(),
        avgScore: data['avgScore'],
        totalLogs: data['total'],
        streak: data['streak'],
        moodCounts: data['moodCounts'],
        allEntries: await _loadEntries(fullHistory: true),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(pdfPath)],
          text: 'My MoodGenie Analytics Report',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to generate report: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSpacing = SharedBottomNavigation.reservedHeight(context);

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2D2545)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mood Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D2545),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Get the most recently fetched data by calling the Future directly,
              // or rely on a state variable if preferred. Since it's quick, we can fetch it again for the export.
              _loadAnalytics().then((data) => _exportPdf(data));
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.primaryDeep,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Stack(
              children: [
                Positioned.fill(child: const AppBackground()),
                const SafeArea(
                  bottom: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                SharedBottomNavigation(
                  currentIndex: 1,
                  onTap: (index) {
                    if (index != 1) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                ),
              ],
            );
          }

          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            return Stack(
              children: [
                Positioned.fill(child: const AppBackground()),
                SafeArea(
                  bottom: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('📊', style: TextStyle(fontSize: 64)),
                        SizedBox(height: 16),
                        Text(
                          'No mood data yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D2545),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Log a few moods first 💜',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6D6689),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SharedBottomNavigation(
                  currentIndex: 1,
                  onTap: (index) {
                    if (index != 1) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                ),
              ],
            );
          }

          final data = snapshot.data!;
          final avgScore = data['avgScore'] as double;
          final chartBars = data['chartBars'] as List<Map<String, dynamic>>;
          final moodCounts = data['moodCounts'] as Map<String, int>;
          final streak = data['streak'] as int;
          final total = data['total'] as int;

          return Stack(
            children: [
              Positioned.fill(child: const AppBackground()),
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, bottomSpacing + 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mood Analytics',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildToggleSelector(),
                      const SizedBox(height: 20),
                      _buildOverviewCard(avgScore, total),
                      const SizedBox(height: 20),
                      _buildWeeklyTrendCard(chartBars),
                      const SizedBox(height: 20),
                      _buildMoodDistributionCard(moodCounts, total),
                      const SizedBox(height: 20),
                      _buildInsightsCard(),
                      const SizedBox(height: 20),
                      _buildStreakCard(streak),
                    ],
                  ),
                ),
              ),
              SharedBottomNavigation(
                currentIndex: 1,
                onTap: (index) {
                  if (index != 1) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(double avgScore, int total) {
    final percentage = ((avgScore - 5.0) / 5.0 * 100).clamp(-100, 100);
    final isPositive = percentage >= 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Mood Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF002B5B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primaryDeep.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isMonthly ? 'Last 30 Days' : 'Last 7 Days',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avgScore.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDeep,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '/10',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6D6689),
                  ),
                ),
              ),
              const Spacer(),
              if (percentage.abs() > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: isPositive
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFFF5252),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${percentage.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isPositive
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF5252),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            total > 5
                ? 'Great progress this week! 🎉'
                : 'Keep logging to see trends! 💜',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6D6689),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isMonthly = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isMonthly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !_isMonthly
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Weekly',
                    style: TextStyle(
                      fontWeight: !_isMonthly
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: !_isMonthly
                          ? AppColors.primaryDeep
                          : const Color(0xFF6D6689),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isMonthly = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isMonthly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isMonthly
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Monthly',
                    style: TextStyle(
                      fontWeight: _isMonthly
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: _isMonthly
                          ? AppColors.primaryDeep
                          : const Color(0xFF6D6689),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendCard(List<Map<String, dynamic>> chartBars) {
    final days = chartBars.map((e) => e['label'] as String).toList();
    final heights = chartBars
        .map((e) => (e['intensity'] as double) * 10)
        .toList();

    final colors = [
      AppColors.primaryLight,
      AppColors.primary,
      AppColors.accentCyan,
      AppColors.primaryMid,
      AppColors.primary,
      AppColors.primaryDeep,
      AppColors.accentCyan,
    ];

    // Find max height for scaling
    final maxHeight = heights.isEmpty
        ? 100.0
        : heights.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📈 Trend',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF002B5B),
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primaryDeep.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _isMonthly ? 'Last 30 Days' : 'Last 7 Days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart area with background grid
          Container(
            height: 140,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.04),
                  AppColors.accentCyan.withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                chartBars.length,
                (i) => _buildTrendBar(
                  days[i],
                  heights[i],
                  maxHeight,
                  colors[i % colors.length],
                  i,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Low', AppColors.primaryLight),
              const SizedBox(width: 16),
              _buildLegendItem('Medium', AppColors.primary),
              const SizedBox(width: 16),
              _buildLegendItem('High', AppColors.primaryDeep),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6D6689),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendBar(
    String day,
    double height,
    double maxHeight,
    Color color,
    int index,
  ) {
    // Scale height relative to max (min 15%, max 80% of available space)
    final scaledHeight = maxHeight > 0
        ? ((height / maxHeight) * 80).clamp(15.0, 80.0)
        : 15.0;
    final intensity = (height / 10).clamp(0.0, 10.0);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Value label on top of bar
            if (intensity > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.2),
                      color.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  intensity.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.2,
                  ),
                ),
              ),

            // The bar
            Flexible(
              child: Container(
                width: double.infinity,
                height: scaledHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color,
                      color.withValues(alpha: 0.75),
                      color.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.7),
                      blurRadius: 4,
                      offset: const Offset(0, -1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Shimmer effect (glossy top)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: math.max(scaledHeight * 0.3, 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.5),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Day label
            Text(
              day,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF002B5B),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodDistributionCard(Map<String, int> moodCounts, int total) {
    if (moodCounts.isEmpty || total == 0) return const SizedBox.shrink();

    final moodColors = {
      'great': AppColors.primaryDeep,
      'good': AppColors.primary,
      'okay': AppColors.accentCyan,
      'bad': AppColors.primaryLight,
      'terrible': AppColors.captionLight,
      'anxious': AppColors.primarySoft,
      'calm': AppColors.accentCyan,
      'excited': AppColors.primary,
      'tired': AppColors.primarySoft,
      'stressed': AppColors.primaryMid,
      'happy': AppColors.primaryDeep,
      'sad': AppColors.primaryLight,
      'angry': AppColors.captionLight,
    };

    // Consolidate identical moods and match case natively
    final normalizedCounts = <String, int>{};
    for (final entry in moodCounts.entries) {
      final key = entry.key.toLowerCase();
      normalizedCounts[key] = (normalizedCounts[key] ?? 0) + entry.value;
    }

    final sortedMoods = normalizedCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Limit to top 6 to prevent over-cluttering the track
    final topMoods = sortedMoods.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mood Breakdown',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF002B5B),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$total Logs',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Horizontal Stacked Bar
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primary.withValues(alpha: 0.05), // fallback bg
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: topMoods.map((entry) {
                  final color = moodColors[entry.key] ?? AppColors.primary;
                  return Expanded(
                    flex: entry.value,
                    child: Container(color: color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Professional Legend Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: topMoods.map((entry) {
              final mood = entry.key;
              final count = entry.value;
              final percentage = (count / total * 100).round();
              final color = moodColors[mood] ?? AppColors.primary;

              return SizedBox(
                width: 140, // Keeps grid clean
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mood.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D6689),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF002B5B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb, color: AppColors.accentCyan, size: 24),
              SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF002B5B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInsightItem('Your mood peaks on weekends'),
          _buildInsightItem('Morning entries show better moods'),
          _buildInsightItem('Keep tracking to see more patterns'),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primaryDeep.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Text('🔥', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$streak Day Streak',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF002B5B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streak > 0
                      ? 'Amazing! Keep tracking daily! 🎯'
                      : 'Start your streak today!',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6D6689),
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
