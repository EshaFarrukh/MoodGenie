import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../src/auth/models/user_model.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';
import '../../services/therapist_service.dart';
import 'therapist_chat_screen.dart';
import 'widgets/therapist_ui.dart';

class TherapistUserDetailScreen extends StatelessWidget {
  const TherapistUserDetailScreen({super.key, required this.user});

  final AppUser user;

  bool get _hasConsent {
    final therapistId = FirebaseAuth.instance.currentUser?.uid;
    return therapistId != null &&
        user.consentedTherapists.contains(therapistId);
  }

  @override
  Widget build(BuildContext context) {
    final therapistId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final therapistService = TherapistService();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Patient Overview',
          style: TextStyle(color: AppColors.headingDark),
        ),
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: TherapistResponsiveContainer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 920;
                    final moodSection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TherapistSectionHeader(
                          icon: Icons.insights_rounded,
                          title: 'Mood insight',
                          subtitle: _hasConsent
                              ? 'Recent shared mood logs are summarized here to support session preparation.'
                              : 'Mood history appears here only when the patient shares it for care.',
                        ),
                        const SizedBox(height: TherapistSpacing.m),
                        if (therapistId.isEmpty)
                          const TherapistEmptyState(
                            icon: Icons.lock_outline_rounded,
                            title: 'Therapist sign-in required',
                            message:
                                'Mood insight becomes available once a signed-in therapist opens this patient record.',
                          )
                        else
                          StreamBuilder<List<Map<String, dynamic>>>(
                            stream: therapistService.getPatientRecentMoods(
                              user.uid,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const TherapistLoadingSkeleton(
                                  lines: 4,
                                  showAvatar: true,
                                );
                              }
                              if (snapshot.hasError) {
                                if (_isPermissionIssue(snapshot.error)) {
                                  return const TherapistEmptyState(
                                    icon: Icons.lock_outline_rounded,
                                    title: 'Shared mood data is locked',
                                    message:
                                        'This patient has not shared mood history with you yet. Mood analytics will appear here automatically once consent is provided.',
                                  );
                                }
                                return TherapistEmptyState(
                                  icon: Icons.error_outline_rounded,
                                  title: 'Could not load shared mood history',
                                  message:
                                      'The patient overview is still available, but mood history could not be loaded right now.',
                                );
                              }
                              final moods = snapshot.data ?? const [];
                              return _MoodInsightSection(moods: moods);
                            },
                          ),
                      ],
                    );

                    final careHistorySection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TherapistSectionHeader(
                          icon: Icons.history_rounded,
                          title: 'Care history',
                          subtitle:
                              'Recent appointment context between you and this patient for quick demo-ready review.',
                        ),
                        const SizedBox(height: TherapistSpacing.m),
                        if (therapistId.isEmpty)
                          const TherapistEmptyState(
                            icon: Icons.schedule_outlined,
                            title: 'Session context unavailable',
                            message:
                                'Past session context appears here when a therapist is signed in.',
                          )
                        else
                          StreamBuilder<List<SessionModel>>(
                            stream: therapistService.watchPatientSessionHistory(
                              therapistId,
                              user.uid,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const TherapistLoadingSkeleton(
                                  lines: 3,
                                  showAvatar: true,
                                );
                              }
                              if (snapshot.hasError) {
                                return const TherapistEmptyState(
                                  icon: Icons.error_outline_rounded,
                                  title: 'Could not load session context',
                                  message:
                                      'Try opening this patient again in a moment. The therapist workspace is still available.',
                                );
                              }
                              return _CareHistorySection(
                                sessions:
                                    snapshot.data ?? const <SessionModel>[],
                              );
                            },
                          ),
                      ],
                    );

                    final quickActions = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TherapistSectionHeader(
                          icon: Icons.flash_on_rounded,
                          title: 'Quick actions',
                          subtitle:
                              'Open secure therapist-to-patient messaging directly from this clinical summary.',
                        ),
                        const SizedBox(height: TherapistSpacing.m),
                        TherapistSurfaceCard(
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryFaint,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: const Text(
                                  'Message patient',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.headingDark,
                                  ),
                                ),
                                subtitle: const Text(
                                  'Open the secure therapist chat workspace.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TherapistChatScreen(
                                        therapistId: user.uid,
                                        therapistName: user.name ?? 'Patient',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _PatientIdentityCard(
                                  user: user,
                                  hasConsent: _hasConsent,
                                ),
                              ),
                              const SizedBox(width: TherapistSpacing.l),
                              Expanded(flex: 2, child: quickActions),
                            ],
                          )
                        else ...[
                          _PatientIdentityCard(
                            user: user,
                            hasConsent: _hasConsent,
                          ),
                          const SizedBox(height: TherapistSpacing.xl),
                          quickActions,
                        ],
                        const SizedBox(height: TherapistSpacing.xl),
                        moodSection,
                        const SizedBox(height: TherapistSpacing.xl),
                        careHistorySection,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientIdentityCard extends StatelessWidget {
  const _PatientIdentityCard({required this.user, required this.hasConsent});

  final AppUser user;
  final bool hasConsent;

  @override
  Widget build(BuildContext context) {
    final joined = DateFormat('MMM d, yyyy').format(user.createdAt);
    return TherapistSummaryCard(
      title: user.name ?? 'Patient',
      subtitle: user.email,
      trailing: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
      ),
      child: Wrap(
        spacing: TherapistSpacing.s,
        runSpacing: TherapistSpacing.s,
        children: [
          _PatientChip(icon: Icons.badge_rounded, label: 'Joined $joined'),
          _PatientChip(
            icon: hasConsent
                ? Icons.lock_open_rounded
                : Icons.lock_outline_rounded,
            label: hasConsent ? 'Mood data shared' : 'Mood data private',
          ),
          _PatientChip(
            icon: Icons.privacy_tip_outlined,
            label: user.consentAccepted
                ? 'App consent accepted'
                : 'Consent pending',
          ),
        ],
      ),
    );
  }
}

class _PatientChip extends StatelessWidget {
  const _PatientChip({required this.icon, required this.label});

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
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: TherapistSpacing.xs),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodInsightSection extends StatelessWidget {
  const _MoodInsightSection({required this.moods});

  final List<Map<String, dynamic>> moods;

  @override
  Widget build(BuildContext context) {
    if (moods.isEmpty) {
      return TherapistEmptyState(
        icon: Icons.mood_outlined,
        title: 'No shared moods yet',
        message:
            'The patient has consented, but there are no recent mood logs to review yet.',
      );
    }

    final latestMood = (_coerceMoodText(moods.first['mood']) ?? 'recent')
        .trim();
    final intensity = (moods.first['intensity'] as num?)?.toInt() ?? 5;
    return Column(
      children: [
        TherapistSurfaceCard(
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primaryFaint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    _emojiForMood(latestMood),
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              const SizedBox(width: TherapistSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_titleCase(latestMood)} most recently shared',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.headingDark,
                      ),
                    ),
                    const SizedBox(height: TherapistSpacing.xxs),
                    Text(
                      'Latest intensity recorded at $intensity/10. Use this as context, not a diagnosis.',
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.bodyMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TherapistSpacing.m),
        ...moods.map((mood) => _MoodHistoryItem(mood: mood)),
      ],
    );
  }

  String _emojiForMood(String mood) {
    switch (mood.trim().toLowerCase()) {
      case 'happy':
        return '😊';
      case 'calm':
        return '😌';
      case 'sad':
        return '😔';
      case 'anxious':
        return '😰';
      case 'angry':
        return '😠';
      default:
        return '🙂';
    }
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return 'Recent mood';
    }
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}

class _MoodHistoryItem extends StatelessWidget {
  const _MoodHistoryItem({required this.mood});

  final Map<String, dynamic> mood;

  @override
  Widget build(BuildContext context) {
    final moodName = (_coerceMoodText(mood['mood']) ?? 'Unknown').trim();
    final note = (_coerceMoodText(mood['note']) ?? '').trim();
    final intensity = (mood['intensity'] as num?)?.toInt() ?? 5;
    final date = _resolveMoodDate(mood);

    return Padding(
      padding: const EdgeInsets.only(bottom: TherapistSpacing.m),
      child: TherapistSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    moodName.isEmpty
                        ? 'Recent mood'
                        : '${moodName[0].toUpperCase()}${moodName.substring(1)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headingDark,
                    ),
                  ),
                ),
                TherapistStatusBadge(
                  label: 'Intensity $intensity/10',
                  foreground: AppColors.primaryDeep,
                  background: AppColors.primaryFaint,
                  icon: Icons.favorite_outline_rounded,
                ),
              ],
            ),
            if (date != null) ...[
              const SizedBox(height: TherapistSpacing.xs),
              Text(
                DateFormat('EEE, MMM d • h:mm a').format(date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: TherapistSpacing.s),
              Text(
                note,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppColors.bodyMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CareHistorySection extends StatelessWidget {
  const _CareHistorySection({required this.sessions});

  final List<SessionModel> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const TherapistEmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No session history yet',
        message:
            'Once this patient has appointment activity with you, the latest care timeline will appear here.',
      );
    }

    return Column(
      children: sessions
          .map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: TherapistSpacing.m),
              child: _SessionHistoryItem(session: session),
            ),
          )
          .toList(),
    );
  }
}

class _SessionHistoryItem extends StatelessWidget {
  const _SessionHistoryItem({required this.session});

  final SessionModel session;

  @override
  Widget build(BuildContext context) {
    final summary = _sessionSummary(session);
    final statusStyle = _statusStyle(session.status);
    final occurredAt = session.updatedAt ?? session.scheduledAt;

    return TherapistSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryFaint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: TherapistSpacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat(
                        'EEE, MMM d • h:mm a',
                      ).format(session.scheduledAt),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.headingDark,
                      ),
                    ),
                    const SizedBox(height: TherapistSpacing.xxs),
                    Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.bodyMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TherapistSpacing.s),
              TherapistStatusBadge(
                label: session.status.label,
                icon: statusStyle.$3,
                foreground: statusStyle.$1,
                background: statusStyle.$2,
              ),
            ],
          ),
          if ((session.notes?.trim().isNotEmpty ?? false) ||
              (session.decisionReason?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: TherapistSpacing.s),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(TherapistSpacing.s),
              decoration: BoxDecoration(
                color: AppColors.surfaceWarm,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _notesLabel(session),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: TherapistSpacing.s),
          Text(
            'Last updated ${DateFormat('MMM d • h:mm a').format(occurredAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

String? _coerceMoodText(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return null;
}

bool _isPermissionIssue(Object? error) {
  final raw = (error ?? '').toString().toLowerCase();
  return raw.contains('permission-denied') ||
      raw.contains('missing or insufficient permissions') ||
      raw.contains('insufficient permissions');
}

String _sessionSummary(SessionModel session) {
  switch (session.status) {
    case AppointmentStatus.requested:
      return 'Appointment request awaiting therapist review.';
    case AppointmentStatus.confirmed:
      return 'Confirmed care session ready for follow-up.';
    case AppointmentStatus.completed:
      return 'Completed session recorded for this patient.';
    case AppointmentStatus.cancelled:
      return 'Cancelled appointment in the shared care timeline.';
    case AppointmentStatus.rejected:
      return 'Request was reviewed and not accepted.';
    case AppointmentStatus.noShow:
      return 'Session marked as no-show.';
  }
}

(Color, Color, IconData) _statusStyle(AppointmentStatus status) {
  switch (status) {
    case AppointmentStatus.confirmed:
      return (
        AppColors.primaryDeep,
        AppColors.primaryFaint,
        Icons.check_circle_outline_rounded,
      );
    case AppointmentStatus.completed:
      return (
        AppColors.success,
        AppColors.success.withValues(alpha: 0.12),
        Icons.task_alt_rounded,
      );
    case AppointmentStatus.requested:
      return (
        AppColors.warning,
        AppColors.warning.withValues(alpha: 0.16),
        Icons.hourglass_top_rounded,
      );
    case AppointmentStatus.cancelled:
    case AppointmentStatus.rejected:
    case AppointmentStatus.noShow:
      return (
        AppColors.error,
        AppColors.error.withValues(alpha: 0.12),
        Icons.warning_amber_rounded,
      );
  }
}

String _notesLabel(SessionModel session) {
  final notes = session.notes?.trim();
  final reason = session.decisionReason?.trim();
  if (notes != null &&
      notes.isNotEmpty &&
      reason != null &&
      reason.isNotEmpty) {
    return 'Notes: $notes\nReason: $reason';
  }
  if (notes != null && notes.isNotEmpty) {
    return 'Notes: $notes';
  }
  if (reason != null && reason.isNotEmpty) {
    return 'Reason: $reason';
  }
  return '';
}

DateTime? _resolveMoodDate(Map<String, dynamic> mood) {
  final resolved = mood['resolvedAt'];
  if (resolved is DateTime) {
    return resolved;
  }
  for (final key in const ['selectedDate', 'createdAt', 'timestamp']) {
    final value = mood[key];
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}
