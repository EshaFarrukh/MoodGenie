// lib/screens/mood/mood_analytics_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:moodgenie/src/theme/app_theme.dart';

class MoodAnalyticsScreen extends StatelessWidget {
  const MoodAnalyticsScreen({super.key});

  Future<Map<String, dynamic>> _loadAnalytics() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};

    final snap = await FirebaseFirestore.instance
        .collection('moods')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: false)
        .limit(30)
        .get();

    if (snap.docs.isEmpty) return {};

    final entries = snap.docs.map((d) {
      final data = d.data();
      final ts = data['createdAt'] as Timestamp;
      final date = ts.toDate();
      final intensity = (data['intensity'] as num?)?.toDouble() ?? 5.0;
      final mood = (data['mood'] ?? 'unknown') as String;

      return {
        'date': DateTime(date.year, date.month, date.day),
        'intensity': intensity,
        'mood': mood,
      };
    }).toList();

    // Calculate stats
    final last7 = entries.length > 7 ? entries.sublist(entries.length - 7) : entries;
    final avgScore = last7.fold<double>(0, (sum, e) => sum + (e['intensity'] as double)) / last7.length;
    
    // Mood distribution
    final moodCounts = <String, int>{};
    for (final e in last7) {
      final mood = e['mood'] as String;
      moodCounts[mood] = (moodCounts[mood] ?? 0) + 1;
    }

    // Streak
    final today = DateTime.now();
    var streak = 0;
    for (var i = 0; i < 30; i++) {
      final checkDate = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final hasEntry = entries.any((e) {
        final entryDate = e['date'] as DateTime;
        return entryDate.year == checkDate.year &&
            entryDate.month == checkDate.month &&
            entryDate.day == checkDate.day;
      });
      if (hasEntry) {
        streak++;
      } else {
        break;
      }
    }

    return {
      'avgScore': avgScore,
      'entries': last7,
      'moodCounts': moodCounts,
      'streak': streak,
      'total': last7.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF7A6FA2)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mood Analytics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4A3B6B),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return Center(
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
                      color: Color(0xFF4A3B6B),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Log a few moods first 💜',
                    style: TextStyle(fontSize: 14, color: Color(0xFF7A6FA2)),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final avgScore = data['avgScore'] as double;
          final entries = data['entries'] as List;
          final moodCounts = data['moodCounts'] as Map<String, int>;
          final streak = data['streak'] as int;
          final total = data['total'] as int;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(avgScore, total),
                const SizedBox(height: 20),
                _buildWeeklyTrendCard(entries),
                const SizedBox(height: 20),
                _buildMoodDistributionCard(moodCounts, total),
                const SizedBox(height: 20),
                _buildInsightsCard(),
                const SizedBox(height: 20),
                _buildStreakCard(streak),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(double avgScore, int total) {
    final percentage = ((avgScore - 5.0) / 5.0 * 100).clamp(-100, 100);
    final isPositive = percentage >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Mood Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Last 7 Days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
                  color: Colors.white,
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
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
              const Spacer(),
              if (percentage.abs() > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? const Color(0xFF4ECDC4).withOpacity(0.9)
                        : const Color(0xFFFF6B6B).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${percentage.abs().toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            total > 5
                ? 'Great progress this week! 🎉'
                : 'Keep logging to see trends! 💜',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendCard(List entries) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final heights = entries.length < 7
        ? List.generate(entries.length, (i) => (entries[i]['intensity'] as double) * 10)
        : List.generate(7, (i) => (entries[i]['intensity'] as double) * 10);

    final colors = [
      const Color(0xFF9B8FD8),
      AppColors.primary,
      const Color(0xFF9B8FD8),
      const Color(0xFF7B6FD8),
      AppColors.primary,
      AppColors.primaryDeep,
      const Color(0xFF7B6FD8),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8DAFF).withOpacity(0.3),
            const Color(0xFFFFE8D9).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFFFFF).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A3B6B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(
              math.min(heights.length, 7),
              (i) => _buildTrendBar(
                days[i],
                heights[i],
                colors[i % colors.length],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBar(String day, double height, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: math.max(20, height.clamp(20, 100)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, color.withOpacity(0.6)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A6FA2),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodDistributionCard(Map<String, int> moodCounts, int total) {
    final moodEmojis = {
      'happy': '😊',
      'sad': '😔',
      'angry': '😠',
      'anxious': '😰',
      'calm': '😌',
      'excited': '🤩',
      'tired': '😴',
      'stressed': '😓',
    };

    final moodColors = {
      'happy': AppColors.primaryDeep,
      'excited': AppColors.primary,
      'calm': const Color(0xFF9B8FD8),
      'sad': const Color(0xFFB8ACFF),
      'anxious': const Color(0xFFD8A6FF),
      'angry': const Color(0xFFFFB6C1),
      'tired': const Color(0xFFC9C0E8),
      'stressed': const Color(0xFFE8DAFF),
    };

    final sortedMoods = moodCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE8DAFF).withOpacity(0.3),
            const Color(0xFFFFE8D9).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFFFFF).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mood Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4A3B6B),
            ),
          ),
          const SizedBox(height: 20),
          ...sortedMoods.take(3).map((entry) {
            final mood = entry.key;
            final count = entry.value;
            final percentage = (count / total * 100).round();
            final emoji = moodEmojis[mood] ?? '😐';
            final color = moodColors[mood] ?? const Color(0xFF9B8FD8);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMoodRow(emoji, mood, percentage, color),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMoodRow(String emoji, String label, int percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A3B6B),
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: color.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFE8D9).withOpacity(0.3),
            const Color(0xFFE8DAFF).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFFFFF).withOpacity(0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb, color: Color(0xFFFFB347), size: 24),
              SizedBox(width: 8),
              Text(
                'Insights',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A3B6B),
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
                color: Color(0xFF7A6FA2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB347), Color(0xFFFF9A4D)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB347).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
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
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  streak > 0
                      ? 'Amazing! Keep tracking daily! 🎯'
                      : 'Start your streak today!',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
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
