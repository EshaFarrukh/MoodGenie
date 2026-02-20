import 'dart:ui';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../src/services/mood_repository.dart';
import 'mood_history_screen.dart';
import 'package:moodgenie/src/theme/app_theme.dart';

class MoodLogScreen extends StatefulWidget {
  const MoodLogScreen({super.key});

  @override
  State<MoodLogScreen> createState() => _MoodLogScreenState();
}

class _MoodLogScreenState extends State<MoodLogScreen> {
  String _selectedMood = 'Happy';
  double _intensity = 7; // 1..10
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteC = TextEditingController();
  bool _saving = false;

  final List<_MoodOption> _moods = const [
    _MoodOption(label: 'Anxious', emoji: '😰', pillColor: Color(0xFFFFE4E1)),
    _MoodOption(label: 'Sad', emoji: '😢', pillColor: Color(0xFFE8DAFF)),
    _MoodOption(label: 'Angry', emoji: '😠', pillColor: Color(0xFFFFD4D4)),
    _MoodOption(label: 'Stressed', emoji: '😫', pillColor: Color(0xFFFFE8D9)),
    _MoodOption(label: 'Tired', emoji: '😴', pillColor: Color(0xFFE0E7FF)),
    _MoodOption(label: 'Calm', emoji: '😌', pillColor: Color(0xFFD4F1F4)),
    _MoodOption(label: 'Happy', emoji: '😊', pillColor: Color(0xFFFFF4D9)),
    _MoodOption(label: 'Excited', emoji: '🤩', pillColor: Color(0xFFFFE8F5)),
    _MoodOption(label: 'Grateful', emoji: '🥰', pillColor: Color(0xFFFFE4E1)),
    _MoodOption(label: 'Confident', emoji: '😎', pillColor: Color(0xFFE8DAFF)),
    _MoodOption(label: 'Loved', emoji: '🥹', pillColor: Color(0xFFFFD9E8)),
    _MoodOption(label: 'Energetic', emoji: '⚡', pillColor: Color(0xFFFFF0CF)),
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
      'Sunday'
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
      'December'
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
              primary: Color(0xFF7B5CFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2D2545),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MoodHistoryScreen(),
      ),
    );
  }

  Future<void> _saveMood() async {
    setState(() => _saving = true);
    try {
      final repository = context.read<MoodRepository>();
      await repository.addMood(
        mood: _selectedMood,
        intensity: _intensity.round(),
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
                      colors: [Color(0xFFFFB06A), Color(0xFFFF7F72)],
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
                          color: Color(0xFF2D2545),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your mood has been logged',
                        style: TextStyle(
                          color: Color(0xFF6D6689),
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
              color: const Color(0xFFFFB06A).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2), // Shortened duration for snappier feel
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
              color: const Color(0xFFFFD7DB).withOpacity(0.5),
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 🌈 Background
          Positioned.fill(
            child: const AppBackground(),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🎨 Glass Header
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFFFFFF).withOpacity(0.30),
                              const Color(0xFFE8DAFF).withOpacity(0.25),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFFFFFFFF).withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            if (Navigator.canPop(context))
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Color(0xFF2D2545),
                                    size: 28,
                                  ),
                                ),
                              ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '✨ Log Your Mood',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF2D2545),
                                      height: 1.2,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'How are you feeling today?',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF7A6FA2),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 😊 Mood selection
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Mood',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D2545),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Select how you\'re feeling right now',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF7A6FA2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          alignment: WrapAlignment.start,
                          children: _moods.map((m) {
                            return _MoodPill(
                              emoji: m.emoji,
                              label: m.label,
                              selected: _selectedMood == m.label,
                              pillColor: m.pillColor,
                              onTap: () => setState(() => _selectedMood = m.label),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📊 Intensity slider
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Intensity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D2545),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'How strong is this feeling?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7A6FA2),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),

                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Low',
                              style: TextStyle(
                                color: Color(0xFF9B8FD8),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'High',
                              style: TextStyle(
                                color: Color(0xFF9B8FD8),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 8,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: const Color(0xFFE8DAFF).withOpacity(0.4),
                            thumbColor: AppColors.primaryDeep,
                            overlayColor: AppColors.primary.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _intensity,
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: _intensity.round().toString(),
                            onChanged: (v) => setState(() => _intensity = v),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(10, (i) {
                              final n = i + 1;
                              return SizedBox(
                                width: 24,
                                child: Center(
                                  child: Text(
                                    '$n',
                                    style: TextStyle(
                                      color: _intensity.round() == n
                                          ? AppColors.primaryDeep
                                          : const Color(0xFF9B8FD8),
                                      fontWeight: _intensity.round() == n
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📅 Date picker
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFFFFFFF).withOpacity(0.28),
                                const Color(0xFFE8DAFF).withOpacity(0.22),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFFFFFFF).withOpacity(0.55),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.primaryDeep,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Date',
                                      style: TextStyle(
                                        color: Color(0xFF9A92B8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatHeaderDate(_selectedDate),
                                      style: const TextStyle(
                                        color: Color(0xFF2D2545),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF9B8FD8),
                                size: 26,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📝 Note field
                  const Text(
                    'Add a Note (Optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2D2545),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFFFFFF).withOpacity(0.28),
                              const Color(0xFFE8DAFF).withOpacity(0.22),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFFFFFF).withOpacity(0.55),
                            width: 1.5,
                          ),
                        ),
                        child: TextField(
                          controller: _noteC,
                          minLines: 4,
                          maxLines: 6,
                          style: const TextStyle(
                            color: Color(0xFF2D2545),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            height: 1.5,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'What made you feel this way? Any thoughts to share?',
                            hintStyle: TextStyle(
                              color: Color(0xFF9B8FD8),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(18),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 💾 Save button
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFFFB06A), Color(0xFFFF7F72)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF8A5C).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveMood,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          'Save Mood',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_rounded, size: 18, color: Color(0xFF9B8FD8)),
                      SizedBox(width: 8),
                      Text(
                        'Only you can see this',
                        style: TextStyle(
                          color: Color(0xFF7A6FA2),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: TextButton(
                      onPressed: _openHistory,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: const Color(0xFFE8DAFF).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: AppColors.primaryDeep,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'View Mood History',
                            style: TextStyle(
                              color: AppColors.primaryDeep,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // 🧭 Footer Navigation
          Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withOpacity(0.40), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
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
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _FooterNavItem(
                        icon: Icons.emoji_emotions_outlined,
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
}

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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFF8A5C) : const Color(0xFF9E9E9E),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? const Color(0xFFFF8A5C) : const Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFFFFF).withOpacity(0.25),
                const Color(0xFFE8DAFF).withOpacity(0.20),
              ],
            ),
            border: Border.all(
              color: const Color(0xFFFFFFFF).withOpacity(0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MoodPill extends StatelessWidget {
  const _MoodPill({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.pillColor,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final Color pillColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(
          minWidth: 100,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    pillColor.withOpacity(0.95),
                    pillColor.withOpacity(0.85),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFFFFFF).withOpacity(0.30),
                    const Color(0xFFE8DAFF).withOpacity(0.22),
                  ],
                ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : const Color(0xFFFFFFFF).withOpacity(0.55),
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 19),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF2D2545) : AppColors.primaryDeep,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
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
