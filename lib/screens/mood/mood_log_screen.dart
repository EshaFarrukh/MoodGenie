import 'package:moodgenie/src/theme/app_background.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../src/services/mood_repository.dart';
import 'mood_history_screen.dart';
import 'package:moodgenie/src/theme/app_theme.dart';
import 'package:moodgenie/screens/home/widgets/shared_bottom_navigation.dart';

class MoodLogScreen extends StatefulWidget {
  const MoodLogScreen({super.key});

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen> {
  String _selectedMood = 'Happy';
  double _intensity = 7; // 1..10

  // New metrics
  int _energyLevel = 3; // 1..5
  int _stressLevel = 5; // 1..10
  int _waterIntake = 0; // 0..8
  double _sleepHours = 7.0; // 0..12
  final List<String> _activities = [];

  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteC = TextEditingController();
  bool _saving = false;

  final List<_MoodOption> _moods = const [
    _MoodOption(label: 'Anxious', emoji: '😰', pillColor: Color(0xFFE0F2FE)),
    _MoodOption(label: 'Sad', emoji: '😢', pillColor: Color(0xFFE0F2FE)),
    _MoodOption(label: 'Angry', emoji: '😠', pillColor: Color(0xFFE0F2FE)),
    _MoodOption(label: 'Stressed', emoji: '😫', pillColor: Color(0xFFE0F2FE)),
    _MoodOption(label: 'Tired', emoji: '😴', pillColor: Color(0xFFE0F2FE)),
    _MoodOption(label: 'Calm', emoji: '😌', pillColor: Color(0xFFBDE4F4)),
    _MoodOption(label: 'Happy', emoji: '😊', pillColor: Color(0xFFBDE4F4)),
    _MoodOption(label: 'Excited', emoji: '🤩', pillColor: Color(0xFFBDE4F4)),
    _MoodOption(label: 'Grateful', emoji: '🥰', pillColor: Color(0xFFBDE4F4)),
    _MoodOption(label: 'Confident', emoji: '😎', pillColor: Color(0xFFBDE4F4)),
    _MoodOption(label: 'Loved', emoji: '🥹', pillColor: Color(0xFFE0F2FE)),
    _MoodOption(label: 'Energetic', emoji: '⚡', pillColor: Color(0xFFBDE4F4)),
  ];

  @override
  void dispose() {
    _noteC.dispose();
    super.dispose();
  }

  String _formatHeaderDate(DateTime d) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
    final w = weekdays[d.weekday - 1];
    final m = months[d.month - 1];
    return '$w, $m ${d.day}';
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF002B5B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _openHistory() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const MoodHistoryScreen()));
  }

  Future<void> _saveMood() async {
    setState(() => _saving = true);
    try {
      final repository = context.read<MoodRepository>();
      await repository.addMood(
        mood: _selectedMood,
        intensity: _intensity.round(),
        energyLevel: _energyLevel,
        stressLevel: _stressLevel,
        waterIntake: _waterIntake,
        sleepHours: _sleepHours,
        activities: _activities,
        note: _noteC.text.trim(),
        date: _dateOnly(_selectedDate),
      );

      if (!mounted) return;

      // Show themed success notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDeep],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mood Saved Successfully! ✨',
                        style: TextStyle(
                          color: Color(0xFF002B5B),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your mood has been logged',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(
            seconds: 2,
          ), // Shortened duration for snappier feel
          elevation: 8,
        ),
      );

      // Clear the note field
      _noteC.clear();

      // Automatically close the screen after a short delay for "optimistic" feel
      // delay lets the user see the "Success" toast for a split second
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD7DB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.error_rounded,
                    color: Color(0xFFFF5252),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Failed to Save Mood',
                        style: TextStyle(
                          color: Color(0xFF2D2545),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$e',
                        style: const TextStyle(
                          color: Color(0xFF6D6689),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: const Color(0xFFFFD7DB).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
          elevation: 8,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSpacing = SharedBottomNavigation.reservedHeight(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 🌈 Background
          Positioned.fill(child: const AppBackground()),

          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🎨 Header with back button and icon badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                                'Log Your Mood',
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
                                'How are you feeling today?',
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
                            Icons.sentiment_satisfied_alt_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📅 Date — redesigned, moved above mood
                  GestureDetector(
                    onTap: _pickDate,
                    child: _GlassCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  AppColors.primaryDeep.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.calendar_today_rounded,
                              color: AppColors.primaryDeep,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatHeaderDate(_selectedDate),
                                  style: const TextStyle(
                                    color: Color(0xFF002B5B),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit_calendar_rounded,
                              color: AppColors.primaryDeep,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 😊 Mood selection (unchanged)
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How do you feel?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF002B5B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap the emotion that best describes you',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.85,
                          children: _moods.map((m) {
                            final isSelected = _selectedMood == m.label;
                            return _MoodEmojiCard(
                              emoji: m.emoji,
                              label: m.label,
                              selected: isSelected,
                              onTap: () =>
                                  setState(() => _selectedMood = m.label),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📊 Intensity — redesigned
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Intensity Level',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF002B5B),
                                ),
                              ),
                            ),
                            // Value badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDeep,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDeep.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_intensity.round()}/10',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Segmented intensity bar
                        Row(
                          children: List.generate(10, (i) {
                            final n = i + 1;
                            final isActive = _intensity.round() >= n;
                            final isExact = _intensity.round() == n;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _intensity = n.toDouble()),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: isExact ? 40 : 32,
                                  margin: EdgeInsets.only(right: i < 9 ? 4 : 0),
                                  decoration: BoxDecoration(
                                    gradient: isActive
                                        ? LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              AppColors.primary.withValues(
                                                alpha: 0.3 + (n / 10) * 0.7,
                                              ),
                                              AppColors.primaryDeep.withValues(
                                                alpha: 0.3 + (n / 10) * 0.7,
                                              ),
                                            ],
                                          )
                                        : null,
                                    color: isActive
                                        ? null
                                        : const Color(0xFFEEF2F7),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isExact
                                        ? [
                                            BoxShadow(
                                              color: AppColors.primaryDeep
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$n',
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : AppColors.textSecondary
                                                  .withValues(alpha: 0.5),
                                        fontWeight: isExact
                                            ? FontWeight.w900
                                            : FontWeight.w700,
                                        fontSize: isExact ? 14 : 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Barely noticeable',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'Overwhelming',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.6,
                                ),
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildEnergyLevel(),
                  const SizedBox(height: 16),
                  _buildStressLevel(),
                  const SizedBox(height: 16),
                  _buildWaterIntake(),
                  const SizedBox(height: 16),
                  _buildSleepTracker(),
                  const SizedBox(height: 16),
                  _buildActivities(),
                  const SizedBox(height: 16),

                  // 📝 Note field — wrapped in a card
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.edit_note_rounded,
                                color: Color(0xFF43A047),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add a Note',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF002B5B),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Optional — jot down your thoughts',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.08),
                            ),
                          ),
                          child: TextField(
                            controller: _noteC,
                            minLines: 3,
                            maxLines: 5,
                            style: const TextStyle(
                              color: Color(0xFF002B5B),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.6,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'What made you feel this way?',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 💾 Save button
                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDeep],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDeep.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveMood,
                        icon: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_rounded, size: 22),
                        label: Text(
                          _saving ? 'Saving...' : 'Save Mood',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Privacy badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Your data is private and secure',
                          style: TextStyle(
                            color: AppColors.primaryDeep,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // History link
                  Center(
                    child: TextButton.icon(
                      onPressed: _openHistory,
                      icon: const Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: AppColors.primaryDeep,
                      ),
                      label: const Text(
                        'View Mood History',
                        style: TextStyle(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        backgroundColor: AppColors.primaryLight.withValues(
                          alpha: 0.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: bottomSpacing),
                ],
              ),
            ),
          ),

          // Footer pinned to the bottom
          SharedBottomNavigation(
            currentIndex: 1, // Mood tab
            onTap: (index) {
              if (index != 1) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                // Note: to properly switch tabs on the home screen from here, you would typically use a global state (e.g., Provider/Riverpod)
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyLevel() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Energy Level',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF002B5B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final val = index + 1;
              final active = _energyLevel >= val;
              return GestureDetector(
                onTap: () => setState(() => _energyLevel = val),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    active ? Icons.bolt_rounded : Icons.bolt_outlined,
                    color: active
                        ? const Color(0xFFFFB300)
                        : AppColors.textSecondary.withValues(alpha: 0.3),
                    size: 38,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStressLevel() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stress Level',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF002B5B),
                ),
              ),
              if (_stressLevel > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStressColor(
                      _stressLevel,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_stressLevel/10',
                    style: TextStyle(
                      color: _getStressColor(_stressLevel),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(10, (index) {
              final val = index + 1;
              final isSelected = _stressLevel == val;
              final isUnder = _stressLevel >= val;
              final baseColor = _getStressColor(val);

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _stressLevel = val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    height: isSelected ? 44 : (isUnder ? 32 : 28),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      gradient: isUnder
                          ? LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                baseColor.withValues(
                                  alpha: isSelected ? 0.9 : 0.4,
                                ),
                                baseColor.withValues(
                                  alpha: isSelected ? 0.6 : 0.2,
                                ),
                              ],
                            )
                          : null,
                      color: isUnder ? null : const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: baseColor.withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.spa_rounded,
                    size: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Relaxed',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Overwhelmed',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.water_drop_rounded,
                    size: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStressColor(int level) {
    if (level <= 3) return AppColors.accentBright; // Calm Cyan
    if (level <= 6) return AppColors.primaryMid; // Moderate Blue
    return AppColors.primaryDeep; // Overwhelmed Navy
  }

  Widget _buildWaterIntake() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water Intake',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF002B5B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(8, (index) {
              final val = index + 1;
              final active = _waterIntake >= val;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_waterIntake == val) {
                      _waterIntake = val - 1;
                    } else {
                      _waterIntake = val;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    active
                        ? Icons.water_drop_rounded
                        : Icons.water_drop_outlined,
                    color: active
                        ? AppColors.primary
                        : AppColors.textSecondary.withValues(alpha: 0.3),
                    size: 30,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepTracker() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Sleep / Rest',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF002B5B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.dark_mode_rounded,
                    size: 18,
                    color: AppColors.primaryMid,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${_sleepHours.toStringAsFixed(1)} hrs',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryMid,
              inactiveTrackColor: const Color(0xFFF1F4F8),
              thumbColor: AppColors.primaryDeep,
              overlayColor: AppColors.primaryMid.withValues(alpha: 0.2),
              trackHeight: 12.0,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 14.0,
                pressedElevation: 8.0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 28.0),
              trackShape: const RoundedRectSliderTrackShape(),
            ),
            child: Slider(
              value: _sleepHours,
              min: 0,
              max: 16,
              divisions: 32, // 0.5 hour increments
              onChanged: (val) => setState(() => _sleepHours = val),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0h',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '8h',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '16h',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivities() {
    final acts = [
      'Work',
      'Exercise',
      'Reading',
      'Family',
      'Friends',
      'Gaming',
      'Relaxing',
      'Chores',
      'Shopping',
      'Travel',
      'Hobbies',
    ];
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activities & Impact',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF002B5B),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: acts.map((act) {
              final active = _activities.contains(act);
              return FilterChip(
                label: Text(act),
                selected: active,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _activities.add(act);
                    } else {
                      _activities.remove(act);
                    }
                  });
                },
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primaryDeep,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: active
                      ? AppColors.primaryDeep
                      : const Color(0xFF3D4F6F),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
                backgroundColor: const Color(0xFFF7F9FC),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.88),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MoodEmojiCard extends StatelessWidget {
  const _MoodEmojiCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDeep],
                )
              : null,
          color: selected ? null : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.accentCyan.withValues(alpha: 0.6)
                : AppColors.primary.withValues(alpha: 0.06),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(fontSize: selected ? 32 : 26),
              child: Text(emoji),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF3D4F6F),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                fontSize: 11,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodOption {
  final String label;
  final String emoji;
  final Color pillColor;

  const _MoodOption({
    required this.label,
    required this.emoji,
    required this.pillColor,
  });
}
