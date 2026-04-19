import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../src/notifications/app_notification_service.dart';
import '../../src/notifications/notification_models.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  NotificationPreferencesModel? _preferences;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cached = context.read<AppNotificationService>().cachedPreferences;
    if (cached != null) {
      _preferences = cached;
      _loading = false;
      unawaited(_loadPreferences(forceRefresh: true, showSpinner: false));
    } else {
      _loadPreferences();
    }
  }

  Future<void> _loadPreferences({
    bool forceRefresh = false,
    bool showSpinner = true,
  }) async {
    final service = context.read<AppNotificationService>();
    if (showSpinner) {
      setState(() => _loading = true);
    }
    try {
      final preferences = await service.fetchPreferences(
        forceRefresh: forceRefresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _preferences = preferences;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      if (_preferences == null || showSpinner) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _savePreferences() async {
    final preferences = _preferences;
    if (preferences == null || _saving) {
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await context
          .read<AppNotificationService>()
          .savePreferences(preferences);
      if (!mounted) {
        return;
      }
      setState(() {
        _preferences = saved;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification preferences saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _pickTime({
    required String currentValue,
    required ValueChanged<String> onSelected,
  }) async {
    final parts = currentValue.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 20,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '00') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) {
      return;
    }
    onSelected(
      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Notification Preferences',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.headingDark,
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : _savePreferences,
                        child: Text(_saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  )
                else if (_preferences == null)
                  const Expanded(
                    child: Center(
                      child: Text('Could not load notification preferences.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        _SectionCard(
                          title: 'Push permission',
                          subtitle:
                              'Review push permission and device registration status.',
                          child: Consumer<AppNotificationService>(
                            builder: (context, notificationService, _) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current status: ${notificationService.permissionStatus}',
                                    style: const TextStyle(
                                      color: AppColors.headingDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Enable push to receive mood reminders, mood forecasts, and appointment updates directly on your device.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: notificationService
                                        .requestPermissionAndRegister,
                                    icon: const Icon(
                                      Icons.notifications_active,
                                    ),
                                    label: const Text(
                                      'Enable push notifications',
                                    ),
                                  ),
                                  if (notificationService
                                          .lastRegistrationError !=
                                      null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFF59E0B),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notificationService
                                                .lastRegistrationError!,
                                            style: const TextStyle(
                                              color: AppColors.headingDark,
                                              fontWeight: FontWeight.w700,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          OutlinedButton.icon(
                                            onPressed: notificationService
                                                .retryRegistration,
                                            icon: const Icon(
                                              Icons.refresh_rounded,
                                            ),
                                            label: const Text(
                                              'Retry device registration',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Delivery channels',
                          subtitle: 'Choose where updates should reach you.',
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Push notifications'),
                                value: _preferences!.pushEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    pushEnabled: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Email notifications'),
                                value: _preferences!.emailEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    emailEnabled: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('In-app inbox'),
                                value: _preferences!.inAppEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    inAppEnabled: value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Wellness notifications',
                          subtitle:
                              'Control mood reminders, explicit forecast nudges, and quote delivery.',
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Daily mood reminders'),
                                value: _preferences!.dailyMoodReminderEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    dailyMoodReminderEnabled: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Mood forecast notifications',
                                ),
                                subtitle: const Text(
                                  'Use explicit future mood predictions when enough data exists.',
                                ),
                                value: _preferences!.moodForecastEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    moodForecastEnabled: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Mood quotes'),
                                value: _preferences!.moodQuotesEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    moodQuotesEnabled: value,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ChoiceRow(
                                label: 'Wellness frequency',
                                value: _preferences!.wellnessFrequency,
                                options: const ['low', 'standard', 'high'],
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    wellnessFrequency: value,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ChoiceRow(
                                label: 'Quote tone',
                                value: _preferences!.quoteTone,
                                options: const [
                                  'gentle',
                                  'uplifting',
                                  'direct',
                                ],
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    quoteTone: value,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ChoiceRow(
                                label: 'Prediction style',
                                value: _preferences!.predictionStyle,
                                options: const ['explicit'],
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    predictionStyle: value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Appointments',
                          subtitle:
                              'These settings apply to booking, approval, rejection, cancellation, and reminder events.',
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Appointment push updates'),
                                value: _preferences!.appointmentPushEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    appointmentPushEnabled: value,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Appointment emails'),
                                value: _preferences!.appointmentEmailEnabled,
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    appointmentEmailEnabled: value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Timing and privacy',
                          subtitle:
                              'Quiet hours and preview settings keep notifications respectful.',
                          child: Column(
                            children: [
                              _TimeRow(
                                label: 'Daily reminder time',
                                value: _preferences!.preferredReminderTime,
                                onTap: () => _pickTime(
                                  currentValue:
                                      _preferences!.preferredReminderTime,
                                  onSelected: (value) => setState(
                                    () => _preferences = _preferences!.copyWith(
                                      preferredReminderTime: value,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _TimeRow(
                                label: 'Quiet hours start',
                                value: _preferences!.quietHoursStart,
                                onTap: () => _pickTime(
                                  currentValue: _preferences!.quietHoursStart,
                                  onSelected: (value) => setState(
                                    () => _preferences = _preferences!.copyWith(
                                      quietHoursStart: value,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _TimeRow(
                                label: 'Quiet hours end',
                                value: _preferences!.quietHoursEnd,
                                onTap: () => _pickTime(
                                  currentValue: _preferences!.quietHoursEnd,
                                  onSelected: (value) => setState(
                                    () => _preferences = _preferences!.copyWith(
                                      quietHoursEnd: value,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                initialValue: _preferences!.timezone,
                                decoration: const InputDecoration(
                                  labelText: 'Timezone',
                                  hintText: 'Asia/Karachi',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    timezone: value.trim(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ChoiceRow(
                                label: 'Language',
                                value: _preferences!.locale,
                                options: const ['en', 'ur'],
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    locale: value,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _ChoiceRow(
                                label: 'Lock screen preview',
                                value: _preferences!.lockScreenPreviewMode,
                                options: const ['generic', 'detailed'],
                                onChanged: (value) => setState(
                                  () => _preferences = _preferences!.copyWith(
                                    lockScreenPreviewMode: value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  label: Text(option),
                  selected: value == option,
                  onSelected: (_) => onChanged(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.schedule_rounded, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
