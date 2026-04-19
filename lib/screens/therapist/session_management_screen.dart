import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/therapist_controller.dart';
import '../../models/session_model.dart';
import '../../src/auth/models/user_model.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';
import 'video_call_screen.dart';
import 'widgets/therapist_ui.dart';

class SessionManagementScreen extends StatelessWidget {
  const SessionManagementScreen({super.key, required this.session});

  final SessionModel session;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TherapistController>();
    final isPending = session.status == AppointmentStatus.requested;
    final isConfirmed = session.status == AppointmentStatus.confirmed;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Session Management',
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
                    final actionSection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TherapistSectionHeader(
                          icon: Icons.playlist_add_check_circle_rounded,
                          title: 'Actions',
                          subtitle: isPending
                              ? 'Approve or decline this booking request with a clear therapist response.'
                              : isConfirmed
                              ? 'Manage the confirmed session, secure call access, and attendance outcome.'
                              : 'This appointment is already in a completed state. Review the latest note below.',
                        ),
                        const SizedBox(height: TherapistSpacing.m),
                        if (isPending)
                          _PendingActions(
                            session: session,
                            onAccept: () => _handleAccept(context),
                            onDecline: () => _handleReject(context),
                          )
                        else if (isConfirmed)
                          _ConfirmedActions(
                            onStartCall: () => _handleStartCall(context),
                            onComplete: () => _handleComplete(context),
                            onCancel: () => _handleCancel(context),
                            onNoShow: () => _handleNoShow(context),
                          )
                        else
                          TherapistSurfaceCard(
                            color: Colors.white.withValues(alpha: 0.9),
                            child: Row(
                              children: [
                                const TherapistStatusBadge(
                                  label: 'Finalized record',
                                  foreground: AppColors.primaryDeep,
                                  background: AppColors.primaryFaint,
                                  icon: Icons.check_circle_outline_rounded,
                                ),
                                const SizedBox(width: TherapistSpacing.s),
                                Expanded(
                                  child: Text(
                                    session.decisionReason?.trim().isNotEmpty ==
                                            true
                                        ? session.decisionReason!.trim()
                                        : 'No additional therapist note was attached to the latest status change.',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: AppColors.bodyMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );

                    final detailSection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TherapistSectionHeader(
                          icon: Icons.fact_check_rounded,
                          title: 'Session details',
                          subtitle:
                              'Review the secure appointment record before taking action.',
                        ),
                        const SizedBox(height: TherapistSpacing.m),
                        _SessionInfoCard(session: session),
                      ],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<AppUser?>(
                          future: controller.getUserById(session.userId),
                          builder: (context, snapshot) {
                            final patient = snapshot.data;
                            return _SessionSummaryHeader(
                              session: session,
                              patientName:
                                  patient?.name ??
                                  session.userName ??
                                  'Patient',
                              patientEmail:
                                  patient?.email ?? 'Patient email unavailable',
                            );
                          },
                        ),
                        const SizedBox(height: TherapistSpacing.xl),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: detailSection),
                              const SizedBox(width: TherapistSpacing.l),
                              Expanded(flex: 4, child: actionSection),
                            ],
                          )
                        else ...[
                          detailSection,
                          const SizedBox(height: TherapistSpacing.xl),
                          actionSection,
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Selector<TherapistController, bool>(
            selector: (_, value) => value.isLoading,
            builder: (context, isLoading, child) {
              if (!isLoading) {
                return const SizedBox.shrink();
              }
              return Container(
                color: Colors.black.withValues(alpha: 0.18),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept(BuildContext context) async {
    final controller = context.read<TherapistController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.acceptSession(session.sessionId);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Booking request approved.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleReject(BuildContext context) async {
    final reason = await TherapistReasonDialog.prompt(
      context,
      title: 'Decline booking request',
      hintText:
          'Tell the patient why this request cannot be accepted right now.',
      actionLabel: 'Decline request',
    );
    if (reason == null || reason.trim().isEmpty || !context.mounted) {
      return;
    }

    final controller = context.read<TherapistController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.rejectSession(session.sessionId, reason: reason);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Booking request declined.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleComplete(BuildContext context) async {
    final controller = context.read<TherapistController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.markSessionCompleted(session.sessionId);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Session marked as completed.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleCancel(BuildContext context) async {
    final reason = await TherapistReasonDialog.prompt(
      context,
      title: 'Cancel confirmed session',
      hintText: 'Explain why this confirmed session is being cancelled.',
      actionLabel: 'Cancel session',
    );
    if (reason == null || reason.trim().isEmpty || !context.mounted) {
      return;
    }
    final controller = context.read<TherapistController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.cancelSession(session.sessionId, reason: reason);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Confirmed session cancelled.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleNoShow(BuildContext context) async {
    final reason = await TherapistReasonDialog.prompt(
      context,
      title: 'Mark patient as no-show',
      hintText: 'Capture the attendance note for this no-show decision.',
      actionLabel: 'Mark no-show',
    );
    if (reason == null || reason.trim().isEmpty || !context.mounted) {
      return;
    }
    final controller = context.read<TherapistController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await controller.markSessionNoShow(session.sessionId, reason: reason);
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Attendance updated to no-show.')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleStartCall(BuildContext context) async {
    final controller = context.read<TherapistController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final roomId = await controller.startVideoSession(session.sessionId);
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            roomId: roomId,
            therapistId: session.userId,
            therapistName: session.userName ?? 'Patient',
            isTherapist: true,
            initiatesCall: true,
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _SessionSummaryHeader extends StatelessWidget {
  const _SessionSummaryHeader({
    required this.session,
    required this.patientName,
    required this.patientEmail,
  });

  final SessionModel session;
  final String patientName;
  final String patientEmail;

  @override
  Widget build(BuildContext context) {
    final scheduleLabel = DateFormat(
      'EEEE, MMM d • h:mm a',
    ).format(session.scheduledAt);
    return TherapistSummaryCard(
      title: patientName,
      subtitle: patientEmail,
      trailing: TherapistStatusBadge.appointment(session.status),
      child: Wrap(
        spacing: TherapistSpacing.s,
        runSpacing: TherapistSpacing.s,
        children: [
          _HeaderChip(icon: Icons.calendar_today_rounded, label: scheduleLabel),
          _HeaderChip(
            icon: Icons.video_call_rounded,
            label: session.status == AppointmentStatus.requested
                ? 'Awaiting therapist decision'
                : 'Secure session workflow',
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

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

class _SessionInfoCard extends StatelessWidget {
  const _SessionInfoCard({required this.session});

  final SessionModel session;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    return TherapistSurfaceCard(
      child: Column(
        children: [
          _infoRow(
            icon: Icons.calendar_month_rounded,
            label: 'Date',
            value: DateFormat('EEEE, MMMM d, yyyy').format(session.scheduledAt),
          ),
          const SizedBox(height: TherapistSpacing.m),
          _infoRow(
            icon: Icons.schedule_rounded,
            label: 'Start time',
            value: timeFormat.format(session.scheduledAt),
          ),
          if (session.scheduledEndAt != null) ...[
            const SizedBox(height: TherapistSpacing.m),
            _infoRow(
              icon: Icons.timelapse_rounded,
              label: 'Ends',
              value: timeFormat.format(session.scheduledEndAt!),
            ),
          ],
          if (session.timezone?.trim().isNotEmpty == true) ...[
            const SizedBox(height: TherapistSpacing.m),
            _infoRow(
              icon: Icons.public_rounded,
              label: 'Timezone',
              value: session.timezone!,
            ),
          ],
          if (session.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: TherapistSpacing.m),
            _noteBlock(title: 'Patient note', value: session.notes!.trim()),
          ],
          if (session.decisionReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: TherapistSpacing.m),
            _noteBlock(
              title: 'Latest status note',
              value: session.decisionReason!.trim(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryFaint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primaryDeep),
        ),
        const SizedBox(width: TherapistSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: TherapistSpacing.xxs),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noteBlock({required String title, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TherapistSpacing.m),
      decoration: BoxDecoration(
        color: TherapistColors.inset,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDeep,
            ),
          ),
          const SizedBox(height: TherapistSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingActions extends StatelessWidget {
  const _PendingActions({
    required this.session,
    required this.onAccept,
    required this.onDecline,
  });

  final SessionModel session;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This request is waiting for your response.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: TherapistSpacing.xs),
          const Text(
            'Accepting confirms the appointment. Declining requires a clear reason so the patient understands the next step.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.bodyMuted,
            ),
          ),
          const SizedBox(height: TherapistSpacing.l),
          TherapistActionButtonSet(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Accept booking'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onDecline,
                  icon: const Icon(Icons.close_rounded),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.45),
                    ),
                  ),
                  label: const Text('Decline with reason'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmedActions extends StatelessWidget {
  const _ConfirmedActions({
    required this.onStartCall,
    required this.onComplete,
    required this.onCancel,
    required this.onNoShow,
  });

  final VoidCallback onStartCall;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onNoShow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TherapistSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Primary session actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingDark,
                ),
              ),
              const SizedBox(height: TherapistSpacing.xs),
              const Text(
                'Start the secure care session or close it out once the visit is complete.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.bodyMuted,
                ),
              ),
              const SizedBox(height: TherapistSpacing.l),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStartCall,
                  icon: const Icon(Icons.video_camera_front_rounded),
                  label: const Text('Start secure video session'),
                ),
              ),
              const SizedBox(height: TherapistSpacing.s),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Mark as completed'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TherapistSpacing.m),
        TherapistSurfaceCard(
          color: Colors.white.withValues(alpha: 0.92),
          borderColor: TherapistColors.pendingSurface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance exceptions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingDark,
                ),
              ),
              const SizedBox(height: TherapistSpacing.xs),
              const Text(
                'These actions change the appointment outcome and require a therapist note.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.bodyMuted,
                ),
              ),
              const SizedBox(height: TherapistSpacing.l),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onNoShow,
                  icon: const Icon(Icons.person_off_rounded),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TherapistColors.pending,
                    side: BorderSide(
                      color: TherapistColors.pending.withValues(alpha: 0.38),
                    ),
                  ),
                  label: const Text('Mark patient as no-show'),
                ),
              ),
              const SizedBox(height: TherapistSpacing.s),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.45),
                    ),
                  ),
                  label: const Text('Cancel confirmed session'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
