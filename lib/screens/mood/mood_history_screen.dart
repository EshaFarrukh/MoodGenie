import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../home/widgets/glass_card.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  DateTime _monthCursor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  bool _loading = true;
  String? _error;

  // raw docs
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Pull enough recent entries to cover calendar and show all history
      final snap = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get();

      _docs = snap.docs;
      _entriesCount = _docs.length;

      _byDay.clear();

      // Build date->entry map (latest entry wins)
      for (final d in _docs) {
        final data = d.data();
        final mood = (data['mood'] as String?) ?? 'Okay';
        final note = (data['note'] as String?) ?? '';
        final intensity = (data['intensity'] as int?) ?? 0;

        DateTime? selectedDate;
        final sd = data['selectedDate'];
        if (sd is Timestamp) {
          selectedDate = sd.toDate();
        } else {
          final ca = data['createdAt'];
          if (ca is Timestamp) selectedDate = ca.toDate();
        }
        if (selectedDate == null) continue;

        final day = _dateOnly(selectedDate);
        if (!_byDay.containsKey(day)) {
          _byDay[day] = _MoodEntry(
            mood: mood,
            note: note,
            intensity: intensity,
            time: selectedDate,
          );
        }
      }

      // Compute avg mood from last 30 days (based on 1..5 scale)
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

      final avg = cnt == 0 ? 4 : (sum / cnt).round(); // default Good
      final avgMood = _score5ToMood(avg);
      _avgMoodLabel = avgMood.label;
      _avgMoodEmoji = avgMood.emoji;

      // Keep selected day valid for current month
      final today = _dateOnly(DateTime.now());
      _selectedDay = _byDay.containsKey(today) ? today : _selectedDay;

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
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
    final lastWeek = nonNull.skip(nonNull.length - 7).map((p) => p.score!).toList();

    final firstAvg = firstWeek.reduce((a, b) => a + b) / firstWeek.length;
    final lastAvg = lastWeek.reduce((a, b) => a + b) / lastWeek.length;

    if (lastAvg > firstAvg + 0.5) return const Color(0xFF4CAF50); // Improving - Green
    if (lastAvg < firstAvg - 0.5) return const Color(0xFFFF6B6B); // Declining - Red
    return const Color(0xFFFF8A5C); // Stable - Orange
  }

  IconData _getTrendIcon() {
    final nonNull = _chart30.where((p) => p.score != null).toList();
    if (nonNull.length < 7) return Icons.trending_flat_rounded;

    final firstWeek = nonNull.take(7).map((p) => p.score!).toList();
    final lastWeek = nonNull.skip(nonNull.length - 7).map((p) => p.score!).toList();

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
    final lastWeek = nonNull.skip(nonNull.length - 7).map((p) => p.score!).toList();

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
        return const _MoodMeta('Terrible', '😣', Color(0xFFB8A8E0)); // Light purple
      case 2:
        return const _MoodMeta('Bad', '😕', Color(0xFFA895D8)); // Medium-light purple
      case 3:
        return const _MoodMeta('Okay', '🙂', Color(0xFF9B8FD8)); // Medium purple
      case 4:
        return const _MoodMeta('Good', '😊', Color(0xFF8B7FD8)); // Medium-dark purple
      case 5:
        return const _MoodMeta('Great', '😁', Color(0xFF6B5CFF)); // Dark purple
      default:
        return const _MoodMeta('Okay', '🙂', Color(0xFF9B8FD8)); // Medium purple
    }
  }

  _MoodMeta _moodMeta(String mood) => _score5ToMood(_moodScore5(mood));

  String _monthLabel(DateTime m) {
    const months = [
      'January','February','March','April','May','June','July','August','September','October','November','December'
    ];
    return '${months[m.month - 1]} ${m.year}';
  }

  String _weekdayLabel(DateTime d) {
    const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
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
      'January','February','March','April','May','June','July','August','September','October','November','December'
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

  List<DateTime?> _buildMonthGrid(DateTime monthFirst) {
    // Sunday-start grid like design
    final first = monthFirst;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;

    // weekday: Mon=1..Sun=7 -> we want Sunday=0..Saturday=6
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

  List<_MoodEntryRow> _rowsForSelectedDay() {
    // show entries for the selected day only
    final list = <_MoodEntryRow>[];

    print('🔍 Filtering entries for selected day: $_selectedDay');
    print('📦 Total docs loaded: ${_docs.length}');

    for (final doc in _docs) {
      final data = doc.data();
      final mood = (data['mood'] as String?) ?? 'Happy';
      final note = (data['note'] as String?) ?? '';
      final intensity = (data['intensity'] as int?) ?? 0;

      DateTime? selectedDate;
      final sd = data['selectedDate'];
      if (sd is Timestamp) {
        selectedDate = sd.toDate();
      } else {
        final ca = data['createdAt'];
        if (ca is Timestamp) selectedDate = ca.toDate();
      }
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

    print('✅ Found ${list.length} entries for selected day');
    for (var i = 0; i < list.length; i++) {
      print('   ${i+1}. ${list[i].mood} at ${_timeLabel(list[i].time)} - Note: "${list[i].note.isEmpty ? "none" : list[i].note.substring(0, list[i].note.length > 20 ? 20 : list[i].note.length)}"');
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/moodgenie_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Glass AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFFFFFF).withOpacity(0.30),
                              const Color(0xFFE8DAFF).withOpacity(0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: const Color(0xFFFFFFFF).withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B7FD8).withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Color(0xFF6B5CFF),
                                size: 24,
                              ),
                            ),
                            const Expanded(
                              child: Center(
                                child: Text(
                                  '📝 Mood History',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF2D2545),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                // optional: open date picker
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF9B8FD8).withOpacity(0.25),
                                      const Color(0xFF7A6FA2).withOpacity(0.20),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Color(0xFF6B5CFF),
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF6B5CFF),
                            strokeWidth: 3,
                          ),
                        )
                      : _error != null
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                      : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary row (Average Mood / Past 30 days / Entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: const Color(0xFF7A6FA2).withOpacity(0.9),
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
                                      const Color(0xFF8B7FD8).withOpacity(0.25),
                                      const Color(0xFF6B5CFF).withOpacity(0.20),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '$_entriesCount Entries',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF6B5CFF),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                          _getTrendColor().withOpacity(0.2),
                                          _getTrendColor().withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getTrendColor().withOpacity(0.3),
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
                                padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
                                child: CustomPaint(
                                  painter: _MoodLineChartPainter(_chart30),
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
                                      const Color(0xFFFFFFFF).withOpacity(0.25),
                                      const Color(0xFFE8DAFF).withOpacity(0.18),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFFFFFFF).withOpacity(0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _InsightItem(
                                        icon: Icons.sentiment_satisfied_rounded,
                                        label: 'Average',
                                        value: _avgMoodEmoji + ' ' + _avgMoodLabel,
                                        color: const Color(0xFF6B5CFF),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 30,
                                      color: const Color(0xFFFFFFFF).withOpacity(0.3),
                                    ),
                                    Expanded(
                                      child: _InsightItem(
                                        icon: Icons.calendar_today_rounded,
                                        label: 'Last 30 Days',
                                        value: '${_chart30.where((p) => p.score != null).length} logs',
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
                                    icon: const Icon(Icons.chevron_left_rounded),
                                    color: const Color(0xFF6B5CFF),
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
                                    icon: const Icon(Icons.chevron_right_rounded),
                                    color: const Color(0xFF6B5CFF),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Weekday labels
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                onSelect: (d) => setState(() => _selectedDay = d),
                                moodMeta: _moodMeta,
                              ),

                              const SizedBox(height: 14),

                              // Entries list (like design)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    _isToday(_selectedDay)
                                        ? 'Today: ${_byDay[_selectedDay] != null ? _moodMeta(_byDay[_selectedDay]!.mood).emoji : '🙂'} '
                                        '${_byDay[_selectedDay] != null ? _moodMeta(_byDay[_selectedDay]!.mood).label : 'Okay'}'
                                        : '${_prettyDate(_selectedDay)}',
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

          // Floating footer (glass)
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.68),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _FooterNavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: false,
                        onTap: () => Navigator.pop(context),
                      ),
                      _FooterNavItem(
                        icon: Icons.favorite_rounded,
                        label: 'Mood',
                        isSelected: true,
                        onTap: () {},
                      ),
                      _FooterNavItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Chat',
                        isSelected: false,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat coming soon 💬')),
                        ),
                      ),
                      _FooterNavItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        isSelected: false,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile coming soon 👤')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
                color: const Color(0xFF7A6FA2).withOpacity(0.8),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFFFFF).withOpacity(0.30),
              const Color(0xFFE8DAFF).withOpacity(0.20),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFFFFF).withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: meta.color.withOpacity(0.08),
              blurRadius: 12,
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        meta.color.withOpacity(0.25),
                        meta.color.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: meta.color.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    meta.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
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
                          color: Color(0xFF2D2545),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: const Color(0xFF7A6FA2).withOpacity(0.8),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_weekdayLabel(r.time)}, ${r.time.day}/${r.time.month}/${r.time.year}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF7A6FA2).withOpacity(0.9),
                              ),
                            ),
                          ),
                          // Show intensity if available
                          if (r.intensity > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    meta.color.withOpacity(0.25),
                                    meta.color.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: meta.color.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${r.intensity}/10',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: meta.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8B7FD8).withOpacity(0.20),
                        const Color(0xFF6B5CFF).withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _timeLabel(r.time),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6B5CFF),
                    ),
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFE8D9).withOpacity(0.7),
                      const Color(0xFFFFD4E8).withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFB06A).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.notes_rounded,
                        size: 16,
                        color: const Color(0xFFFF8A5C).withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r.note.trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D2545),
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
      ..color = const Color(0xFFE8DAFF).withOpacity(0.25)
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

      textPainter.paint(
        canvas,
        Offset(2, y - textPainter.height / 2),
      );
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

    final take = nonNull.length >= 7 ? nonNull.sublist(nonNull.length - 7) : nonNull;

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
      ..color = const Color(0xFF6B5CFF).withOpacity(0.4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (double x = leftPadding; x < leftPadding + chartWidth; x += 10) {
      canvas.drawLine(
        Offset(x, avgY),
        Offset(x + 5, avgY),
        avgLinePaint,
      );
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

    area.lineTo(leftPadding + stepX * (take.length - 1), topPadding + chartHeight);
    area.close();

    // Gradient area fill
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B7FD8).withOpacity(0.3),
          const Color(0xFFFF8E58).withOpacity(0.15),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight));

    canvas.drawPath(area, areaPaint);

    // Line
    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFFFF8E58),
          Color(0xFF8B7FD8),
        ],
      ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight))
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
      final dotOuter = Paint()..color = Colors.white.withOpacity(0.95);
      final dotInner = Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF8E58),
            Color(0xFF8B7FD8),
          ],
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFFFF).withOpacity(0.14),
            const Color(0xFFE8DAFF).withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
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
          final isSelected = day.year == selectedDay.year && day.month == selectedDay.month && day.day == selectedDay.day;

          final hasMood = entry != null;
          final moodColor = hasMood ? moodMeta(entry.mood).color : null;

          return InkWell(
            onTap: () => onSelect(day),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF8B7FD8).withOpacity(0.35),
                          const Color(0xFF6B5CFF).withOpacity(0.25),
                        ],
                      )
                    : hasMood
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              moodColor!.withOpacity(0.20),
                              moodColor.withOpacity(0.10),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.08),
                              const Color(0xFFE8DAFF).withOpacity(0.05),
                            ],
                          ),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8B7FD8).withOpacity(0.6)
                      : hasMood
                          ? moodColor!.withOpacity(0.4)
                          : Colors.white.withOpacity(0.15),
                  width: isSelected ? 2 : hasMood ? 1.5 : 1,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasMood ? FontWeight.w900 : FontWeight.w700,
                        color: hasMood
                            ? const Color(0xFF2D2545)
                            : const Color(0xFF2D2545).withOpacity(0.60),
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
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              moodColor!,
                              moodColor.withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: moodColor.withOpacity(0.5),
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

// -------------------- Legend item --------------------

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.emoji, required this.label});
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF7A6FA2),
          ),
        ),
      ],
    );
  }
}

// -------------------- Footer nav item --------------------

class _FooterNavItem extends StatelessWidget {
  const _FooterNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = const Color(0xFFFF8A5C);
    final unselectedColor = const Color(0xFF9B8FD8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: isSelected ? selectedColor : unselectedColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
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
        Icon(
          icon,
          color: color,
          size: 22,
        ),
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
