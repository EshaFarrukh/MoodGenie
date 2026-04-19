import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodgenie/src/theme/app_background.dart';

import '../../src/services/therapist_booking_service.dart';
import '../../src/theme/app_theme.dart';
import '../home/widgets/glass_card.dart';
import 'my_therapy_requests_screen.dart';
import 'therapist_chat_screen.dart';

class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({super.key, required this.therapistId});

  final String therapistId;

  @override
  State<AppointmentBookingScreen> createState() =>
      _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final _notesController = TextEditingController();
  final TherapistBookingService _bookingService = TherapistBookingService();

  DateTime _selectedDate = DateTime.now();
  String? _selectedSlotId;
  bool _loadingSlots = false;
  bool _submitting = false;
  bool _consentGiven = true;
  bool _acceptingNewPatients = true;
  String? _slotsError;
  String? _submitError;
  String? _therapistTimezone;
  DateTime? _nextAvailableAt;
  List<BookableSlot> _slots = const <BookableSlot>[];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              secondary: AppColors.accentCyan,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedDate = picked;
      _selectedSlotId = null;
    });
    await _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });

    try {
      final snapshot = await _bookingService.fetchPublicAvailability(
        widget.therapistId,
        date: _selectedDate,
      );

      final activeSelection = _selectedSlotId;
      final availableSlots =
          snapshot.slots.where((slot) => slot.status == 'open').toList()
            ..sort((left, right) => left.startAt.compareTo(right.startAt));

      setState(() {
        _acceptingNewPatients = snapshot.acceptingNewPatients;
        _therapistTimezone = snapshot.timezone;
        _nextAvailableAt = snapshot.nextAvailableAt;
        _slots = availableSlots;
        _selectedSlotId =
            availableSlots.any((slot) => slot.slotId == activeSelection)
            ? activeSelection
            : null;
      });
    } catch (error) {
      setState(() {
        _slotsError = error.toString();
        _slots = const <BookableSlot>[];
        _selectedSlotId = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSlots = false);
      }
    }
  }

  Future<void> _submit({required Map<String, dynamic>? therapist}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      return;
    }

    final selectedSlotId = _selectedSlotId;
    if (selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an available time slot.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      await _bookingService.requestAppointment(
        therapistId: widget.therapistId,
        slotId: selectedSlotId,
        consentGiven: _consentGiven,
        notes: _notesController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      final therapistName =
          (therapist?['displayName'] as String?)?.trim().isNotEmpty == true
          ? (therapist!['displayName'] as String).trim()
          : 'your therapist';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your request was sent to $therapistName. You can track it in My Therapy Requests.',
          ),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MyTherapyRequestsScreen()),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitError = 'Could not request appointment: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not request appointment: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, MMM d, yyyy').format(date);
  }

  String _formatTimeRange(BookableSlot slot) {
    return '${DateFormat('h:mm a').format(slot.startAt)} - ${DateFormat('h:mm a').format(slot.endAt)}';
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSlotGrid() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_slotsError != null) {
      return GlassCard(
        gradientColors: const [Colors.white, Color(0xFFF7FBFF)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We could not load live availability right now.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.headingDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _slotsError!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _loadSlots,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_acceptingNewPatients) {
      return GlassCard(
        gradientColors: const [Colors.white, Color(0xFFF7FBFF)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This therapist has paused new requests.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.headingDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Their profile stays visible, but they are not accepting new appointments right now.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            if (_nextAvailableAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Next expected opening: ${DateFormat('EEE, MMM d • h:mm a').format(_nextAvailableAt!)}',
                style: const TextStyle(
                  color: AppColors.primaryDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (_slots.isEmpty) {
      return GlassCard(
        gradientColors: const [Colors.white, Color(0xFFF7FBFF)],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No open slots on this day.',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.headingDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose another date to see live openings. Only truly open slots are shown here.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            if (_nextAvailableAt != null) ...[
              const SizedBox(height: 10),
              Text(
                'Next available: ${DateFormat('EEE, MMM d • h:mm a').format(_nextAvailableAt!)}',
                style: const TextStyle(
                  color: AppColors.primaryDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _slots.map((slot) {
        final isSelected = slot.slotId == _selectedSlotId;
        return GestureDetector(
          onTap: () => setState(() => _selectedSlotId = slot.slotId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 148,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.accentCyan],
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : AppColors.primary.withValues(alpha: 0.15),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.24),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : AppShadows.soft(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('h:mm a').format(slot.startAt),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppColors.headingDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimeRange(slot),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.92)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final therapistRef = FirebaseFirestore.instance
        .collection('public_therapists')
        .doc(widget.therapistId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.08)),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: therapistRef.snapshots(),
              builder: (context, snapshot) {
                final therapist = snapshot.data?.data();
                final name =
                    (therapist?['displayName'] ?? 'Therapist') as String;
                final specialization =
                    (therapist?['specialty'] ?? 'Mental Health') as String;
                final rating = (therapist?['rating'] is num)
                    ? (therapist!['rating'] as num).toDouble()
                    : null;
                final expYears = (therapist?['yearsExperience'] is num)
                    ? (therapist!['yearsExperience'] as num).toInt()
                    : null;

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      floating: true,
                      leading: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      title: const Text('Book Appointment'),
                      centerTitle: true,
                      actions: [
                        IconButton(
                          tooltip: 'My Therapy Requests',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MyTherapyRequestsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          GlassCard(
                            gradientColors: const [
                              Color(0xFFF4EEFF),
                              Color(0xFFFFF7EE),
                            ],
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 14,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.psychology_alt_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        specialization,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (rating != null) ...[
                                            const Icon(
                                              Icons.star_rounded,
                                              size: 16,
                                              color: AppColors.accentCyan,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          if (expYears != null)
                                            Text(
                                              '$expYears years',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TherapistChatScreen(
                                    therapistId: widget.therapistId,
                                    therapistName: name,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    color: AppColors.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Chat with Therapist',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _sectionTitle(
                            'Select a day',
                            subtitle:
                                'Slots come from the therapist’s live weekly schedule and current booking availability.',
                          ),
                          const SizedBox(height: 8),
                          GlassCard(
                            gradientColors: const [
                              Color(0xFFFFFFFF),
                              Color(0xFFF4EEFF),
                            ],
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formatDate(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _pickDate,
                                  child: const Text('Change'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _sectionTitle(
                            'Available slots',
                            subtitle: _therapistTimezone == null
                                ? null
                                : 'Schedule source timezone: $_therapistTimezone. Times shown here are adjusted to your device.',
                          ),
                          const SizedBox(height: 12),
                          _buildSlotGrid(),
                          const SizedBox(height: 24),
                          _sectionTitle(
                            'Care note',
                            subtitle:
                                'Add anything your therapist should know before reviewing this request.',
                          ),
                          const SizedBox(height: 8),
                          GlassCard(
                            gradientColors: const [Colors.white, Colors.white],
                            child: TextField(
                              controller: _notesController,
                              minLines: 4,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                hintText:
                                    'Describe what support you are looking for, goals for the session, or context that will help the therapist review your request.',
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GlassCard(
                            gradientColors: const [Colors.white, Colors.white],
                            child: SwitchListTile.adaptive(
                              value: _consentGiven,
                              contentPadding: EdgeInsets.zero,
                              activeThumbColor: AppColors.primaryDeep,
                              title: const Text(
                                'Share my mood history for care',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.headingDark,
                                ),
                              ),
                              subtitle: const Text(
                                'This lets the therapist view the mood data you have consented to share once the relationship is active.',
                                style: TextStyle(fontSize: 12),
                              ),
                              onChanged: (value) {
                                setState(() => _consentGiven = value);
                              },
                            ),
                          ),
                          if (_submitError != null) ...[
                            const SizedBox(height: 16),
                            GlassCard(
                              gradientColors: const [
                                Color(0xFFFFFBEB),
                                Colors.white,
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'We could not send your request.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.headingDark,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _submitError!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _submitting
                                        ? null
                                        : () => _submit(therapist: therapist),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Retry request'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDeep,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : () => _submit(therapist: therapist),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded),
                                label: Text(
                                  _submitting
                                      ? 'Sending Request...'
                                      : 'Request Appointment',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
