import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../src/services/therapist_booking_service.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';
import 'widgets/therapist_ui.dart';

class TherapistAvailabilityScreen extends StatefulWidget {
  const TherapistAvailabilityScreen({super.key, this.initialSnapshot});

  final TherapistAvailabilitySnapshot? initialSnapshot;

  @override
  State<TherapistAvailabilityScreen> createState() =>
      _TherapistAvailabilityScreenState();
}

class _TherapistAvailabilityScreenState
    extends State<TherapistAvailabilityScreen> {
  final TherapistBookingService _bookingService = TherapistBookingService();
  final TextEditingController _timezoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _acceptingNewPatients = true;
  int _sessionDurationMinutes = 60;
  int _bufferMinutes = 15;
  DateTime? _nextAvailableAt;
  List<TherapistAvailabilityRuleDto> _weeklyRules = _defaultWeeklyRules();
  List<TherapistBlockedDateDto> _blockedDates =
      const <TherapistBlockedDateDto>[];

  @override
  void initState() {
    super.initState();
    if (widget.initialSnapshot != null) {
      _bookingService.cacheMyAvailability(widget.initialSnapshot!);
      _applyAvailability(widget.initialSnapshot!);
      _loading = false;
    } else {
      _loadAvailability();
    }
  }

  @override
  void dispose() {
    _timezoneController.dispose();
    super.dispose();
  }

  static List<TherapistAvailabilityRuleDto> _defaultWeeklyRules() {
    return List<TherapistAvailabilityRuleDto>.generate(7, (index) {
      final weekday = index + 1;
      final enabled = weekday >= DateTime.monday && weekday <= DateTime.friday;
      return TherapistAvailabilityRuleDto(
        weekday: weekday,
        enabled: enabled,
        startTime: '09:00',
        endTime: '17:00',
      );
    });
  }

  String _weekdayLabel(int weekday) {
    const labels = <int, String>{
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return labels[weekday] ?? 'Day';
  }

  TimeOfDay _parseTime(String? value, TimeOfDay fallback) {
    final raw = value?.trim() ?? '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (match == null) {
      return fallback;
    }
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final now = DateTime.now();
    return DateFormat(
      'h:mm a',
    ).format(DateTime(now.year, now.month, now.day, value.hour, value.minute));
  }

  String _timeStorageValue(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _applyAvailability(TherapistAvailabilitySnapshot snapshot) {
    _acceptingNewPatients = snapshot.acceptingNewPatients;
    _sessionDurationMinutes = snapshot.sessionDurationMinutes;
    _bufferMinutes = snapshot.bufferMinutes;
    _nextAvailableAt = snapshot.nextAvailableAt;
    _weeklyRules = snapshot.weeklyRules.isEmpty
        ? _defaultWeeklyRules()
        : snapshot.weeklyRules;
    _blockedDates = snapshot.blockedDates;
    _timezoneController.text = snapshot.timezone;
  }

  Future<void> _loadAvailability() async {
    setState(() => _loading = true);
    try {
      final snapshot = await _bookingService.fetchMyAvailability();
      if (!mounted) {
        return;
      }
      setState(() {
        _applyAvailability(snapshot);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _weeklyRules = _defaultWeeklyRules();
        _timezoneController.text = 'Asia/Karachi';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Using a default weekly schedule while we load your saved availability.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickRuleTime(int index, {required bool isStart}) async {
    final rule = _weeklyRules[index];
    final current = _parseTime(
      isStart ? rule.startTime : rule.endTime,
      isStart
          ? const TimeOfDay(hour: 9, minute: 0)
          : const TimeOfDay(hour: 17, minute: 0),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    final updated = List<TherapistAvailabilityRuleDto>.from(_weeklyRules);
    updated[index] = TherapistAvailabilityRuleDto(
      weekday: rule.weekday,
      enabled: rule.enabled,
      startTime: isStart ? _timeStorageValue(picked) : rule.startTime,
      endTime: isStart ? rule.endTime : _timeStorageValue(picked),
    );
    setState(() => _weeklyRules = updated);
  }

  Future<void> _addBlockedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) {
      return;
    }
    final dateKey = DateFormat('yyyy-MM-dd').format(picked);
    if (_blockedDates.any((entry) => entry.dateKey == dateKey)) {
      return;
    }
    setState(() {
      _blockedDates = [
        ..._blockedDates,
        TherapistBlockedDateDto(dateKey: dateKey, note: 'Unavailable'),
      ]..sort((left, right) => left.dateKey.compareTo(right.dateKey));
    });
  }

  Future<void> _saveAvailability() async {
    final timezone = _timezoneController.text.trim();
    if (timezone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid IANA timezone.')),
      );
      return;
    }

    final invalidRule = _weeklyRules.any((rule) {
      if (!rule.enabled) {
        return false;
      }
      final start = rule.startTime ?? '';
      final end = rule.endTime ?? '';
      return start.isEmpty || end.isEmpty || start.compareTo(end) >= 0;
    });
    if (invalidRule) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Every enabled weekday needs a start time earlier than its end time.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await _bookingService.saveMyAvailability(
        timezone: timezone,
        acceptingNewPatients: _acceptingNewPatients,
        sessionDurationMinutes: _sessionDurationMinutes,
        bufferMinutes: _bufferMinutes,
        weeklyRules: _weeklyRules,
        blockedDates: _blockedDates,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _nextAvailableAt = saved.nextAvailableAt;
        _weeklyRules = saved.weeklyRules;
        _blockedDates = saved.blockedDates;
        _timezoneController.text = saved.timezone;
        _acceptingNewPatients = saved.acceptingNewPatients;
        _sessionDurationMinutes = saved.sessionDurationMinutes;
        _bufferMinutes = saved.bufferMinutes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Availability updated and patient-facing slots refreshed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save availability: $error')),
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Availability & Scheduling',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.headingDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: FilledButton(
                          onPressed: _loading || _saving ? null : _saveAvailability,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                          ),
                          child: Text(_saving ? 'Saving...' : 'Save'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                          child: TherapistResponsiveContainer(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 920;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TherapistSummaryCard(
                                      title: 'Control live bookable time',
                                      subtitle:
                                          'Patients only see real open slots from this schedule. Requests hold a slot immediately and cancelled or rejected requests reopen it.',
                                      trailing: Container(
                                        width: 58,
                                        height: 58,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_month_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                      child: Wrap(
                                        spacing: TherapistSpacing.s,
                                        runSpacing: TherapistSpacing.s,
                                        children: [
                                          _HeroChip(
                                            icon: Icons.public_rounded,
                                            label:
                                                _timezoneController.text.trim().isEmpty
                                                ? 'Timezone not set'
                                                : _timezoneController.text.trim(),
                                          ),
                                          _HeroChip(
                                            icon: _acceptingNewPatients
                                                ? Icons.group_add_rounded
                                                : Icons.pause_circle_outline_rounded,
                                            label: _acceptingNewPatients
                                                ? 'Accepting new patients'
                                                : 'New requests paused',
                                          ),
                                          if (_nextAvailableAt != null)
                                            _HeroChip(
                                              icon: Icons.schedule_rounded,
                                              label:
                                                  'Next opening ${DateFormat('MMM d • h:mm a').format(_nextAvailableAt!)}',
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: TherapistSpacing.xl),
                                    if (isWide)
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child:
                                                _buildPracticeSettingsSection(),
                                          ),
                                          const SizedBox(
                                            width: TherapistSpacing.l,
                                          ),
                                          Expanded(
                                            child: _buildBlockedDatesSection(),
                                          ),
                                        ],
                                      )
                                    else ...[
                                      _buildPracticeSettingsSection(),
                                      const SizedBox(
                                        height: TherapistSpacing.xl,
                                      ),
                                      _buildBlockedDatesSection(),
                                    ],
                                    const SizedBox(height: TherapistSpacing.xl),
                                    const TherapistSectionHeader(
                                      icon: Icons.repeat_rounded,
                                      title: 'Weekly availability rules',
                                      subtitle:
                                          'Define the weekdays, working hours, and recurring availability that generate live slots.',
                                    ),
                                    const SizedBox(height: TherapistSpacing.m),
                                    ...List.generate(
                                      _weeklyRules.length,
                                      _buildRuleCard,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TherapistSectionHeader(
          icon: Icons.settings_suggest_rounded,
          title: 'Practice settings',
          subtitle:
              'Set the operational rules that shape patient-facing slots and request behavior.',
        ),
        const SizedBox(height: TherapistSpacing.m),
        TherapistSurfaceCard(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Accept new patients',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.headingDark,
                  ),
                ),
                subtitle: const Text(
                  'Pause requests without removing your profile or saved availability rules.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                value: _acceptingNewPatients,
                activeThumbColor: AppColors.primaryDeep,
                onChanged: (value) {
                  setState(() => _acceptingNewPatients = value);
                },
              ),
              const Divider(height: 28),
              TextField(
                controller: _timezoneController,
                decoration: InputDecoration(
                  labelText: 'IANA timezone',
                  hintText: 'Asia/Karachi',
                  filled: true,
                  fillColor: TherapistColors.workspaceTint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: TherapistColors.cardBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: TherapistColors.cardBorder,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: TherapistSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: _StepperCard(
                      title: 'Session length',
                      value: '$_sessionDurationMinutes min',
                      onDecrease: _sessionDurationMinutes > 30
                          ? () => setState(() => _sessionDurationMinutes -= 15)
                          : null,
                      onIncrease: _sessionDurationMinutes < 120
                          ? () => setState(() => _sessionDurationMinutes += 15)
                          : null,
                    ),
                  ),
                  const SizedBox(width: TherapistSpacing.m),
                  Expanded(
                    child: _StepperCard(
                      title: 'Buffer',
                      value: '$_bufferMinutes min',
                      onDecrease: _bufferMinutes > 0
                          ? () => setState(() => _bufferMinutes -= 5)
                          : null,
                      onIncrease: _bufferMinutes < 60
                          ? () => setState(() => _bufferMinutes += 5)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlockedDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 640;
            final info = const TherapistSectionHeader(
              icon: Icons.block_rounded,
              title: 'Blocked dates',
              subtitle:
                  'Mark individual dates unavailable when you are away or need to protect your calendar.',
            );
            final action = OutlinedButton.icon(
              onPressed: _addBlockedDate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add blocked date'),
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  info,
                  const SizedBox(height: TherapistSpacing.m),
                  SizedBox(width: double.infinity, child: action),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: TherapistSectionHeader(
                  icon: Icons.block_rounded,
                  title: 'Blocked dates',
                  subtitle:
                      'Mark individual dates unavailable when you are away or need to protect your calendar.',
                )),
                const SizedBox(width: TherapistSpacing.m),
                action,
              ],
            );
          },
        ),
        const SizedBox(height: TherapistSpacing.m),
        if (_blockedDates.isEmpty)
          TherapistEmptyState(
            icon: Icons.event_available_rounded,
            title: 'No blocked dates yet',
            message:
                'You can add specific unavailable dates here without changing your weekly schedule.',
          )
        else
          ..._blockedDates.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: TherapistSpacing.m),
              child: TherapistSurfaceCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: TherapistColors.pendingSurface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.event_busy_rounded,
                        color: TherapistColors.pending,
                      ),
                    ),
                    const SizedBox(width: TherapistSpacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'EEEE, MMM d, yyyy',
                            ).format(DateTime.parse(entry.dateKey)),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.headingDark,
                            ),
                          ),
                          const SizedBox(height: TherapistSpacing.xxs),
                          Text(
                            entry.note?.trim().isNotEmpty == true
                                ? entry.note!
                                : 'Unavailable',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _blockedDates = _blockedDates
                              .where(
                                (blocked) => blocked.dateKey != entry.dateKey,
                              )
                              .toList();
                        });
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRuleCard(int index) {
    final rule = _weeklyRules[index];
    final start = _parseTime(
      rule.startTime,
      const TimeOfDay(hour: 9, minute: 0),
    );
    final end = _parseTime(rule.endTime, const TimeOfDay(hour: 17, minute: 0));

    return Padding(
      padding: const EdgeInsets.only(bottom: TherapistSpacing.m),
      child: TherapistSurfaceCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weekdayLabel(rule.weekday),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingDark,
                        ),
                      ),
                      const SizedBox(height: TherapistSpacing.xxs),
                      Text(
                        rule.enabled
                            ? 'Patients can book within this working window.'
                            : 'Unavailable on this weekday.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: rule.enabled,
                  activeThumbColor: AppColors.primaryDeep,
                  onChanged: (value) {
                    final updated = List<TherapistAvailabilityRuleDto>.from(
                      _weeklyRules,
                    );
                    updated[index] = TherapistAvailabilityRuleDto(
                      weekday: rule.weekday,
                      enabled: value,
                      startTime: rule.startTime,
                      endTime: rule.endTime,
                    );
                    setState(() => _weeklyRules = updated);
                  },
                ),
              ],
            ),
            if (rule.enabled) ...[
              const SizedBox(height: TherapistSpacing.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickRuleTime(index, isStart: true),
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(_formatTimeOfDay(start)),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: TherapistSpacing.s,
                    ),
                    child: Text('to'),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickRuleTime(index, isStart: false),
                      icon: const Icon(Icons.access_time_filled_rounded),
                      label: Text(_formatTimeOfDay(end)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TherapistSpacing.s,
        vertical: TherapistSpacing.s,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: TherapistSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperCard extends StatelessWidget {
  const _StepperCard({
    required this.title,
    required this.value,
    this.onDecrease,
    this.onIncrease,
  });

  final String title;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TherapistSpacing.m),
      decoration: BoxDecoration(
        color: TherapistColors.workspaceTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: TherapistSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: TherapistSpacing.s),
          Row(
            children: [
              _stepperButton(icon: Icons.remove_rounded, onTap: onDecrease),
              const SizedBox(width: TherapistSpacing.s),
              _stepperButton(icon: Icons.add_rounded, onTap: onIncrease),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TherapistColors.cardBorder),
        ),
        child: Icon(
          icon,
          color: onTap == null ? AppColors.captionLight : AppColors.primaryDeep,
        ),
      ),
    );
  }
}
