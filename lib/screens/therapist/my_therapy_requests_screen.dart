import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/session_model.dart';
import '../../src/services/secure_operations_service.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';
import '../home/widgets/glass_card.dart';
import 'therapist_chat_screen.dart';
import 'therapist_list_screen.dart';

class MyTherapyRequestsScreen extends StatefulWidget {
  const MyTherapyRequestsScreen({super.key});

  @override
  State<MyTherapyRequestsScreen> createState() => _MyTherapyRequestsScreenState();
}

class _MyTherapyRequestsScreenState extends State<MyTherapyRequestsScreen> {
  final SecureOperationsService _secureOperations = SecureOperationsService();
  String? _updatingSessionId;

  Future<void> _cancelAppointment(SessionModel session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel appointment?'),
        content: Text(
          session.status == AppointmentStatus.requested
              ? 'This request will be cancelled and the slot will reopen for other patients.'
              : 'This confirmed session will be cancelled and removed from your active therapy schedule.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Appointment'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _updatingSessionId = session.sessionId);
    try {
      await _secureOperations.updateAppointmentStatus(
        session.sessionId,
        AppointmentStatus.cancelled,
        reason: 'Cancelled by patient',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment cancelled.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingSessionId = null);
      }
    }
  }

  String _formatDateTime(DateTime value) {
    return DateFormat('EEE, MMM d • h:mm a').format(value);
  }

  String _formatUpdated(DateTime? value) {
    if (value == null) {
      return 'Updated moments ago';
    }
    return 'Updated ${DateFormat('MMM d, h:mm a').format(value)}';
  }

  Stream<List<SessionModel>> _therapyRequestsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final sessions =
              snapshot.docs
                  .map((doc) => SessionModel.fromMap(doc.data(), doc.id))
                  .toList();

          if (sessions.isEmpty) {
            return <SessionModel>[];
          }

          final therapistIds =
              sessions
                  .map((session) => session.therapistId.trim())
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .toList();

          if (therapistIds.isEmpty) {
            return <SessionModel>[];
          }

          final liveFlags = await Future.wait(
            therapistIds.map(
              (therapistId) async {
                try {
                  final snapshot = await FirebaseFirestore.instance
                      .collection('therapists')
                      .doc(therapistId)
                      .get();
                  return snapshot.exists;
                } catch (_) {
                  return false;
                }
              },
            ),
          );

          final liveTherapistIds = <String>{
            for (var index = 0; index < therapistIds.length; index++)
              if (liveFlags[index]) therapistIds[index],
          };

          final visibleSessions =
              sessions
                  .where(
                    (session) => liveTherapistIds.contains(session.therapistId),
                  )
                  .toList()
                ..sort(
                  (left, right) =>
                      right.scheduledAt.compareTo(left.scheduledAt),
                );

          return visibleSessions;
        });
  }

  Color _statusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.requested:
        return const Color(0xFFE69F00);
      case AppointmentStatus.confirmed:
        return const Color(0xFF1D8348);
      case AppointmentStatus.rejected:
        return const Color(0xFFB3261E);
      case AppointmentStatus.cancelled:
        return const Color(0xFF6B7280);
      case AppointmentStatus.completed:
        return AppColors.primary;
      case AppointmentStatus.noShow:
        return const Color(0xFF8E44AD);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          'My Therapy Requests',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.headingDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: user == null
                      ? _LoggedOutState(onBrowse: () {})
                      : StreamBuilder<List<SessionModel>>(
                          stream: _therapyRequestsStream(user.uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Could not load your therapy requests: ${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              );
                            }

                            final sessions = snapshot.data ?? const <SessionModel>[];

                            if (sessions.isEmpty) {
                              return _EmptyRequestsState(
                                onBrowse: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const TherapistListScreen(),
                                    ),
                                  );
                                },
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: sessions.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final session = sessions[index];
                                final statusColor = _statusColor(session.status);
                                final canCancel = session.status == AppointmentStatus.requested ||
                                    session.status == AppointmentStatus.confirmed;
                                final canOpenChat = session.status ==
                                    AppointmentStatus.confirmed;

                                return GlassCard(
                                  gradientColors: const [
                                    Colors.white,
                                    Color(0xFFF7FBFF),
                                  ],
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            height: 44,
                                            width: 44,
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              session.status == AppointmentStatus.confirmed
                                                  ? Icons.verified_rounded
                                                  : session.status == AppointmentStatus.requested
                                                  ? Icons.schedule_rounded
                                                  : session.status == AppointmentStatus.rejected
                                                  ? Icons.close_rounded
                                                  : session.status == AppointmentStatus.completed
                                                  ? Icons.check_circle_rounded
                                                  : Icons.info_outline_rounded,
                                              color: statusColor,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  session.therapistName ??
                                                      'Therapist',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.headingDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDateTime(session.scheduledAt),
                                                  style: const TextStyle(
                                                    color: AppColors.textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor.withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(999),
                                                  ),
                                                  child: Text(
                                                    session.status.label,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        _formatUpdated(session.updatedAt),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if ((session.notes ?? '').trim().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _InfoBlock(
                                          title: 'Your note',
                                          value: session.notes!.trim(),
                                        ),
                                      ],
                                      if ((session.decisionReason ?? '').trim().isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        _InfoBlock(
                                          title: session.status == AppointmentStatus.rejected
                                              ? 'Therapist decision'
                                              : 'Status note',
                                          value: session.decisionReason!.trim(),
                                          accentColor: statusColor,
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          if (canOpenChat)
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => TherapistChatScreen(
                                                        therapistId:
                                                            session.therapistId,
                                                        therapistName:
                                                            session.therapistName ??
                                                            'Therapist',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(Icons.chat_rounded),
                                                label: const Text('Open Chat'),
                                              ),
                                            ),
                                          if (canOpenChat && canCancel)
                                            const SizedBox(width: 12),
                                          if (canCancel)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: _updatingSessionId ==
                                                        session.sessionId
                                                    ? null
                                                    : () => _cancelAppointment(
                                                        session,
                                                      ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      AppColors.headingDark,
                                                  elevation: 0,
                                                  side: BorderSide(
                                                    color: AppColors.headingDark
                                                        .withValues(alpha: 0.15),
                                                  ),
                                                ),
                                                icon: _updatingSessionId ==
                                                        session.sessionId
                                                    ? const SizedBox(
                                                        height: 16,
                                                        width: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Icon(
                                                        Icons.close_rounded,
                                                      ),
                                                label: Text(
                                                  session.status ==
                                                          AppointmentStatus.requested
                                                      ? 'Cancel Request'
                                                      : 'Cancel Session',
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
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

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.title,
    required this.value,
    this.accentColor,
  });

  final String title;
  final String value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (accentColor ?? AppColors.primary).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: accentColor ?? AppColors.primaryDeep,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  const _EmptyRequestsState({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          gradientColors: const [Colors.white, Color(0xFFF7FBFF)],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.medical_services_outlined,
                size: 52,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'No therapy requests yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Once you request a therapist session, every pending, confirmed, rejected, and completed appointment will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onBrowse,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Browse Therapists'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoggedOutState extends StatelessWidget {
  const _LoggedOutState({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          gradientColors: const [Colors.white, Color(0xFFF7FBFF)],
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 52,
                color: AppColors.primary,
              ),
              SizedBox(height: 16),
              Text(
                'Please sign in to view therapy requests.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
