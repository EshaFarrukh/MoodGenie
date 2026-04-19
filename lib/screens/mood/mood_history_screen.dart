import 'package:moodgenie/src/theme/app_background.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../home/widgets/glass_card.dart';
import 'package:moodgenie/src/theme/app_theme.dart';
import 'package:moodgenie/screens/home/widgets/shared_bottom_navigation.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  static const int _moodHistoryPageSize = 50;
  DateTime _monthCursor = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMoreHistory = false;
  String? _error;
  String? _loadMoreError;

  // raw docs
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastMoodDoc;

  // map dateOnly -> best mood of that day (latest entry)
  final Map<DateTime, _MoodEntry> _byDay = {};

  // last 30 days (dateOnly -> mood score 1..5)
  final List<_ChartPoint> _chart30 = [];

  // summary
  int _entriesCount = 0;
  String _avgMoodLabel = 'Good';
  String _avgMoodEmoji = '😊';

  @override
  void initState() {
    super.initState();
    _loadMoods();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadMoods() async {
    await _loadMoodPage(refresh: true);
  }

  DateTime? _resolveMoodDate(Map<String, dynamic> data) {
    final selectedDate = data['selectedDate'];
    if (selectedDate is Timestamp) {
      return selectedDate.toDate();
    }

    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) {
      return createdAt.toDate();
    }

    final timestamp = data['timestamp'];
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    return null;
  }

  void _rebuildMoodState() {
    _entriesCount = _docs.length;
    _byDay.clear();

    for (final d in _docs) {
      final data = d.data();
      final mood = (data['mood'] as String?) ?? 'Okay';
      final note = (data['note'] as String?) ?? '';
      final intensity = (data['intensity'] as int?) ?? 0;
      final resolvedDate = _resolveMoodDate(data);
      if (resolvedDate == null) {
        continue;
      }

      final day = _dateOnly(resolvedDate);
      if (!_byDay.containsKey(day)) {
        _byDay[day] = _MoodEntry(
          mood: mood,
          note: note,
          intensity: intensity,
          time: resolvedDate,
        );
      }
    }

    final now = DateTime.now();
    final start30 = _dateOnly(now.subtract(const Duration(days: 29)));

    final points = <_ChartPoint>[];
    int sum = 0;
    int cnt = 0;

    for (int i = 0; i < 30; i++) {
      final day = _dateOnly(start30.add(Duration(days: i)));
      final entry = _byDay[day];
      final score = entry == null ? null : _moodScore5(entry.mood);
      if (score != null) {
        sum += score;
        cnt++;
      }
      points.add(_ChartPoint(day: day, score: score));
    }

    _chart30
      ..clear()
      ..addAll(points);

    final avg = cnt == 0 ? 4 : (sum / cnt).round();
    final avgMood = _score5ToMood(avg);
    _avgMoodLabel = avgMood.label;
    _avgMoodEmoji = avgMood.emoji;

    final today = _dateOnly(DateTime.now());
    if (_byDay.containsKey(today)) {
      _selectedDay = today;
    }
  }

  Future<void> _loadMoodPage({required bool refresh}) async {
    if (!refresh && (_loadingMore || !_hasMoreHistory)) {
      return;
    }

    setState(() {
      if (refresh) {
        _loading = true;
        _error = null;
        _loadMoreError = null;
        _lastMoodDoc = null;
        _hasMoreHistory = false;
      } else {
        _loadingMore = true;
        _loadMoreError = null;
      }
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(_moodHistoryPageSize);

      if (!refresh && _lastMoodDoc != null) {
        query = query.startAfterDocument(_lastMoodDoc!);
      }

      final snap = await query.get();

      if (refresh) {
        _docs = snap.docs;
      } else {
        _docs = [..._docs, ...snap.docs];
      }
      _lastMoodDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastMoodDoc;
      _hasMoreHistory = snap.docs.length == _moodHistoryPageSize;
      _rebuildMoodState();

      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        if (refresh) {
          _loading = false;
          _error = e.toString();
        } else {
          _loadingMore = false;
          _loadMoreError = e.toString();
        }
      });
    }
  }

  // ---- Mood mapping (matches your design labels) ----

  int _moodScore5(String mood) {
    switch (mood.trim().toLowerCase()) {
      case 'anxious':
      case 'terrible':
        return 1;
      case 'sad':
      case 'bad':
        return 2;
      case 'okay':
      case 'calm':
        return 3;
      case 'happy':
      case 'good':
        return 4;
      case 'excited':
      case 'grateful':
      case 'confident':
      case 'loved':
      case 'energetic':
      case 'great':
        return 5;
      default:
        return 3;
    }
  }

  // ---- Trend Calculation ----

  Color _getTrendColor() {
    final nonNull = _chart30.where((p) => p.score != null).toList();
    if (nonNull.length < 7) return const Color(0xFF7A6FA2);

    // Compare first week vs last week average
    final firstWeek = nonNull.take(7).map((p) => p.score!).toList();
    final lastWeek = nonNull
        .skip(nonNull.length - 7)
        .map((p) => p.score!)
        .toList();

    final firstAvg = firstWeek.reduce((a, b) => a + b) / firstWeek.length;
    final lastAvg = lastWeek.reduce((a, b) => a + b) / lastWeek.length;

    if (lastAvg > firstAvg + 0.5) {
      return const Color(0xFF4CAF50); // Improving - Green
    }
    if (lastAvg < firstAvg - 0.5) {
      return const Color(0xFFFF6B6B); // Declining - Red
    }
    return const Color(0xFFFF8A5C); // Stable - Orange
  }

  IconData _getTrendIcon() {
    final nonNull = _chart30.where((p) => p.score != null).toList();
    if (nonNull.length < 7) return Icons.trending_flat_rounded;

    final firstWeek = nonNull.take(7).map((p) => p.score!).toList();
    final lastWeek = nonNull
        .skip(nonNull.length - 7)
        .map((p) => p.score!)
        .toList();

    final firstAvg = firstWeek.reduce((a, b) => a + b) / firstWeek.length;
    final lastAvg = lastWeek.reduce((a, b) => a + b) / lastWeek.length;

    if (lastAvg > firstAvg + 0.5) return Icons.trending_up_rounded;
    if (lastAvg < firstAvg - 0.5) return Icons.trending_down_rounded;
    return Icons.trending_flat_rounded;
  }

  String _getTrendLabel() {
    final nonNull = _chart30.where((p) => p.score != null).toList();
    if (nonNull.length < 7) return 'Stable';

    final firstWeek = nonNull.take(7).map((p) => p.score!).toList();
    final lastWeek = nonNull
        .skip(nonNull.length - 7)
        .map((p) => p.score!)
        .toList();

    final firstAvg = firstWeek.reduce((a, b) => a + b) / firstWeek.length;
    final lastAvg = lastWeek.reduce((a, b) => a + b) / lastWeek.length;

    if (lastAvg > firstAvg + 0.5) return 'Improving';
    if (lastAvg < firstAvg - 0.5) return 'Declining';
    return 'Stable';
  }

  // ---- Mood mapping (matches your design labels) ----

  _MoodMeta _score5ToMood(int score) {
    switch (score) {
      case 1:
        return const _MoodMeta(
          'Terrible',
          '😣',
          Color(0xFFB8A8E0),
        ); // Light purple
      case 2:
        return const _MoodMeta(
          'Bad',
          '😕',
          Color(0xFFA895D8),
        ); // Medium-light purple
      case 3:
        return const _MoodMeta(
          'Okay',
          '🙂',
          Color(0xFF9B8FD8),
        ); // Medium purple
      case 4:
        return const _MoodMeta(
          'Good',
          '😊',
          AppColors.primary,
        ); // Medium-dark purple
      case 5:
        return const _MoodMeta(
          'Great',
          '😁',
          AppColors.primaryDeep,
        ); // Dark purple
      default:
        return const _MoodMeta(
          'Okay',
          '🙂',
          Color(0xFF9B8FD8),
        ); // Medium purple
    }
  }

  _MoodMeta _moodMeta(String mood) => _score5ToMood(_moodScore5(mood));

  String _monthLabel(DateTime m) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[m.month - 1]} ${m.year}';
  }

  String _weekdayLabel(DateTime d) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return days[d.weekday % 7];
  }

  String _timeLabel(DateTime d) {
    int h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $ampm';
  }

  String _prettyDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${_weekdayLabel(d)}, ${months[d.month - 1]} ${d.day}';
  }

  void _prevMonth() {
    setState(() {
      _monthCursor = DateTime(_monthCursor.year, _monthCursor.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _monthCursor = DateTime(_monthCursor.year, _monthCursor.month + 1, 1);
    });
  }

  List<_MoodEntryRow> _rowsForSelectedDay() {
    // show entries for the selected day only
    final list = <_MoodEntryRow>[];

    for (final doc in _docs) {
      final data = doc.data();
      final mood = (data['mood'] as String?) ?? 'Happy';
      final note = (data['note'] as String?) ?? '';
      final intensity = (data['intensity'] as int?) ?? 0;
      final selectedDate = _resolveMoodDate(data);
      if (selectedDate == null) continue;

      final day = _dateOnly(selectedDate);
      // Only include entries for the selected day
      if (day.year == _selectedDay.year &&
          day.month == _selectedDay.month &&
          day.day == _selectedDay.day) {
        list.add(
          _MoodEntryRow(
            day: day,
            time: selectedDate,
            mood: mood,
            note: note,
            intensity: intensity,
          ),
        );
      }
    }

    // newest first
    list.sort((a, b) => b.time.compareTo(a.time));

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSpacing = SharedBottomNavigation.reservedHeight(context);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background
          Positioned.fill(child: const AppBackground()),

          // Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // 🎨 Header matching Mood Log Screen
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.97),
                          Colors.white.withValues(alpha: 0.90),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (Navigator.canPop(context))
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(right: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.primaryDeep,
                                size: 18,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Mood History',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF002B5B),
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Your past emotional journey',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDeep,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDeep.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryDeep,
                            strokeWidth: 3,
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton.icon(
                                  onPressed: _loadMoods,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry history'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            bottomSpacing,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Summary row (Average Mood / Past 30 days / Entries)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Average Mood: $_avgMoodEmoji $_avgMoodLabel',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF2D2545),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Past 30 Days',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(
                                                0xFF7A6FA2,
                                              ).withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.primary.withValues(
                                              alpha: 0.25,
                                            ),
                                            AppColors.primaryDeep.withValues(
                                              alpha: 0.20,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        '$_entriesCount Entries',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primaryDeep,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Quick Mood Check + Chart card
                              GlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '📊 Mood Pattern',
                                                style: TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF2D2545),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Your emotional journey over time',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF7A6FA2),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Trend indicator
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                _getTrendColor().withValues(
                                                  alpha: 0.2,
                                                ),
                                                _getTrendColor().withValues(
                                                  alpha: 0.1,
                                                ),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: _getTrendColor()
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getTrendIcon(),
                                                color: _getTrendColor(),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                _getTrendLabel(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  color: _getTrendColor(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Chart with better height and labels
                                    Container(
                                      height: 200,
                                      width: double.infinity,
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        right: 8,
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      child: CustomPaint(
                                        painter: _MoodLineChartPainter(
                                          _chart30,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 12),

                                    // Insights row
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            const Color(
                                              0xFFFFFFFF,
                                            ).withValues(alpha: 0.25),
                                            const Color(
                                              0xFFE8DAFF,
                                            ).withValues(alpha: 0.18),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFFFFFF,
                                          ).withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _InsightItem(
                                              icon: Icons
                                                  .sentiment_satisfied_rounded,
                                              label: 'Average',
                                              value:
                                                  '$_avgMoodEmoji $_avgMoodLabel',
                                              color: AppColors.primaryDeep,
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 30,
                                            color: const Color(
                                              0xFFFFFFFF,
                                            ).withValues(alpha: 0.3),
                                          ),
                                          Expanded(
                                            child: _InsightItem(
                                              icon:
                                                  Icons.calendar_today_rounded,
                                              label: 'Last 30 Days',
                                              value:
                                                  '${_chart30.where((p) => p.score != null).length} logs',
                                              color: const Color(0xFFFF8A5C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Calendar + list card (big)
                              GlassCard(
                                child: Column(
                                  children: [
                                    // Month header with arrows
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: _prevMonth,
                                          icon: const Icon(
                                            Icons.chevron_left_rounded,
                                          ),
                                          color: AppColors.primaryDeep,
                                        ),
                                        Expanded(
                                          child: Center(
                                            child: Text(
                                              _monthLabel(_monthCursor),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF2D2545),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: _nextMonth,
                                          icon: const Icon(
                                            Icons.chevron_right_rounded,
                                          ),
                                          color: AppColors.primaryDeep,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    // Weekday labels
                                    const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _Weekday('S'),
                                        _Weekday('M'),
                                        _Weekday('T'),
                                        _Weekday('W'),
                                        _Weekday('T'),
                                        _Weekday('F'),
                                        _Weekday('S'),
                                      ],
                                    ),

                                    const SizedBox(height: 10),

                                    // Calendar grid
                                    _CalendarGrid(
                                      monthFirst: _monthCursor,
                                      byDay: _byDay,
                                      selectedDay: _selectedDay,
                                      onSelect: (d) =>
                                          setState(() => _selectedDay = d),
                                      moodMeta: _moodMeta,
                                    ),

                                    const SizedBox(height: 14),

                                    // Entries list (like design)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: Text(
                                          _isToday(_selectedDay)
                                              ? 'Today: ${_byDay[_selectedDay] != null ? _moodMeta(_byDay[_selectedDay]!.mood).emoji : '🙂'} '
                                                    '${_byDay[_selectedDay] != null ? _moodMeta(_byDay[_selectedDay]!.mood).label : 'Okay'}'
                                              : _prettyDate(_selectedDay),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2D2545),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    ..._buildEntryTiles(_rowsForSelectedDay()),
                                    if (_loadMoreError != null) ...[
                                      const SizedBox(height: 12),
                                      Center(
                                        child: Column(
                                          children: [
                                            Text(
                                              _loadMoreError!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  _loadMoodPage(refresh: false),
                                              icon: const Icon(
                                                Icons.refresh_rounded,
                                              ),
                                              label: const Text(
                                                'Retry older history',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (_loadingMore) ...[
                                      const SizedBox(height: 12),
                                      const Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.primaryDeep,
                                        ),
                                      ),
                                    ] else if (_hasMoreHistory) ...[
                                      const SizedBox(height: 12),
                                      Center(
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _loadMoodPage(refresh: false),
                                          icon: const Icon(
                                            Icons.history_toggle_off_rounded,
                                          ),
                                          label: const Text(
                                            'Load older history',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Footer pinned to the bottom
          SharedBottomNavigation(
            currentIndex: 1, // Mood tab
            onTap: (index) {
              if (index != 1) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime d) {
    final t = DateTime.now();
    return d.year == t.year && d.month == t.month && d.day == t.day;
  }

  List<Widget> _buildEntryTiles(List<_MoodEntryRow> rows) {
    if (rows.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No moods logged on this day.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: const Color(0xFF7A6FA2).withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ];
    }

    // Show all entries for the selected day
    return rows.map((r) {
      final meta = _moodMeta(r.mood);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Emoji icon container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(meta.emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF002B5B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _timeLabel(r.time),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.9,
                                ),
                              ),
                            ),
                          ),
                          // Show intensity if available
                          if (r.intensity > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.speed_rounded,
                                    color: Color(0xFFFF9800),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${r.intensity}/10',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF9800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (r.note.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.edit_note_rounded,
                        size: 18,
                        color: AppColors.primaryDeep.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.note.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF3D4F6F),
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }
}

// -------------------- Chart Painter (no fl_chart) --------------------

class _MoodLineChartPainter extends CustomPainter {
  _MoodLineChartPainter(this.points);

  final List<_ChartPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    // Leave space for labels
    const leftPadding = 35.0;
    const rightPadding = 10.0;
    const topPadding = 10.0;
    const bottomPadding = 25.0;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    // Background grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE8DAFF).withValues(alpha: 0.25)
      ..strokeWidth = 1;

    // Draw horizontal grid lines
    final moodLabels = ['Terrible', 'Bad', 'Okay', 'Good', 'Great'];
    for (int i = 0; i < 5; i++) {
      final y = topPadding + chartHeight * (1 - i / 4.0);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      // Y-axis labels
      final textPainter = TextPainter(
        text: TextSpan(
          text: moodLabels[i],
          style: const TextStyle(
            color: Color(0xFF7A6FA2),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(2, y - textPainter.height / 2));
    }

    // Extract visible points
    final nonNull = points.where((p) => p.score != null).toList();
    if (nonNull.length < 2) {
      // Show "No data" message
      final noDataPainter = TextPainter(
        text: const TextSpan(
          text: 'Log more moods to see your pattern',
          style: TextStyle(
            color: Color(0xFF7A6FA2),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: chartWidth);

      noDataPainter.paint(
        canvas,
        Offset(
          leftPadding + (chartWidth - noDataPainter.width) / 2,
          topPadding + (chartHeight - noDataPainter.height) / 2,
        ),
      );
      return;
    }

    final take = nonNull.length >= 7
        ? nonNull.sublist(nonNull.length - 7)
        : nonNull;

    // Calculate average for reference line
    final scores = take.map((p) => p.score!).toList();
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;

    // Map score 1..5 into y coordinate
    double yFor(int score) {
      final t = (score - 1) / 4.0;
      return topPadding + chartHeight * (1 - t);
    }

    final stepX = chartWidth / (take.length - 1);

    // Draw average line (dashed)
    final avgY = yFor(avgScore.round());
    final avgLinePaint = Paint()
      ..color = AppColors.primaryDeep.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (double x = leftPadding; x < leftPadding + chartWidth; x += 10) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 5, avgY), avgLinePaint);
    }

    // Build path
    final path = Path();
    final area = Path();

    for (int i = 0; i < take.length; i++) {
      final x = leftPadding + stepX * i;
      final y = yFor(take[i].score!);
      if (i == 0) {
        path.moveTo(x, y);
        area.moveTo(x, topPadding + chartHeight);
        area.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        area.lineTo(x, y);
      }
    }

    area.lineTo(
      leftPadding + stepX * (take.length - 1),
      topPadding + chartHeight,
    );
    area.close();

    // Gradient area fill
    final areaPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.3),
              const Color(0xFFFF8E58).withValues(alpha: 0.15),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
          );

    canvas.drawPath(area, areaPaint);

    // Line
    final linePaint = Paint()
      ..shader =
          const LinearGradient(
            colors: [Color(0xFFFF8E58), AppColors.primary],
          ).createShader(
            Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
          )
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Dots and date labels
    for (int i = 0; i < take.length; i++) {
      final x = leftPadding + stepX * i;
      final y = yFor(take[i].score!);

      // Dot
      final dotOuter = Paint()..color = Colors.white.withValues(alpha: 0.95);
      final dotInner = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF8E58), AppColors.primary],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 12));

      canvas.drawCircle(Offset(x, y), 8, dotOuter);
      canvas.drawCircle(Offset(x, y), 6, dotInner);

      // Date label (show every other or first/last)
      if (i == 0 || i == take.length - 1 || (take.length <= 7 && i % 2 == 0)) {
        final day = take[i].day;
        final dateText = '${day.month}/${day.day}';
        final datePainter = TextPainter(
          text: TextSpan(
            text: dateText,
            style: const TextStyle(
              color: Color(0xFF7A6FA2),
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        datePainter.paint(
          canvas,
          Offset(x - datePainter.width / 2, topPadding + chartHeight + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -------------------- Calendar --------------------

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.monthFirst,
    required this.byDay,
    required this.selectedDay,
    required this.onSelect,
    required this.moodMeta,
  });

  final DateTime monthFirst;
  final Map<DateTime, _MoodEntry> byDay;
  final DateTime selectedDay;
  final void Function(DateTime d) onSelect;
  final _MoodMeta Function(String mood) moodMeta;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  List<DateTime?> _buildMonthGrid(DateTime monthFirst) {
    final first = monthFirst;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final firstWeekdaySundayIndex = first.weekday % 7;

    final cells = <DateTime?>[];
    for (int i = 0; i < firstWeekdaySundayIndex; i++) {
      cells.add(null);
    }
    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(DateTime(first.year, first.month, day));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildMonthGrid(monthFirst);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: cells.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          final d = cells[i];
          if (d == null) return const SizedBox.shrink();

          final day = _dateOnly(d);
          final entry = byDay[day];
          final isSelected =
              day.year == selectedDay.year &&
              day.month == selectedDay.month &&
              day.day == selectedDay.day;

          final hasMood = entry != null;
          final moodColor = hasMood ? moodMeta(entry.mood).color : null;

          return InkWell(
            onTap: () => onSelect(day),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isSelected
                    ? AppColors.primaryDeep
                    : hasMood
                    ? Colors.white
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryDeep
                      : hasMood
                      ? moodColor!.withValues(alpha: 0.3)
                      : Colors.transparent,
                  width: isSelected
                      ? 2
                      : hasMood
                      ? 1.5
                      : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryDeep.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : hasMood
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasMood || isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : hasMood
                            ? const Color(0xFF2D2545)
                            : const Color(0xFF2D2545).withValues(alpha: 0.40),
                      ),
                    ),
                  ),
                  // Colored indicator dot for mood
                  if (hasMood && !isSelected)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: moodColor!,
                          boxShadow: [
                            BoxShadow(
                              color: moodColor.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A6FA2),
          ),
        ),
      ),
    );
  }
}

// -------------------- Insight Item Widget --------------------

class _InsightItem extends StatelessWidget {
  const _InsightItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A6FA2),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

// -------------------- Models --------------------

class _MoodEntry {
  final String mood;
  final String note;
  final int intensity;
  final DateTime time;

  const _MoodEntry({
    required this.mood,
    required this.note,
    required this.intensity,
    required this.time,
  });
}

class _MoodEntryRow {
  final DateTime day;
  final DateTime time;
  final String mood;
  final String note;
  final int intensity;

  const _MoodEntryRow({
    required this.day,
    required this.time,
    required this.mood,
    required this.note,
    required this.intensity,
  });
}

class _ChartPoint {
  final DateTime day;
  final int? score; // 1..5 or null

  const _ChartPoint({required this.day, required this.score});
}

class _MoodMeta {
  final String label;
  final String emoji;
  final Color color;

  const _MoodMeta(this.label, this.emoji, this.color);
}
