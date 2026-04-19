import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../controllers/therapist_controller.dart';
import '../../../src/auth/models/user_model.dart';
import '../../../src/auth/services/auth_service.dart';
import '../../../src/services/backend_api_client.dart';
import '../../../src/services/privacy_operations_service.dart';
import '../../../src/services/therapist_booking_service.dart';
import '../../../src/theme/app_background.dart';
import '../../../src/theme/app_theme.dart';
import '../../notifications/notification_center_screen.dart';
import '../../notifications/notification_preferences_screen.dart';
import '../edit_therapist_profile_screen.dart';
import '../therapist_availability_screen.dart';
import '../widgets/therapist_ui.dart';

class TherapistProfileTab extends StatefulWidget {
  const TherapistProfileTab({super.key});

  @override
  State<TherapistProfileTab> createState() => _TherapistProfileTabState();
}

class _TherapistProfileTabState extends State<TherapistProfileTab> {
  final TherapistBookingService _bookingService = TherapistBookingService();
  final PrivacyOperationsService _privacyOperations =
      PrivacyOperationsService();
  bool _isSavingAvailability = false;
  bool _isDeletingAccount = false;
  bool? _acceptingNewPatientsOverride;
  TherapistAvailabilitySnapshot? _availabilitySnapshotCache;

  @override
  void initState() {
    super.initState();
    _warmAvailabilityCache();
  }

  Future<void> _warmAvailabilityCache({bool force = false}) async {
    if (!force && _availabilitySnapshotCache != null) {
      return;
    }

    try {
      final snapshot = await _bookingService.fetchMyAvailability();
      if (!mounted) {
        return;
      }
      setState(() {
        _bookingService.cacheMyAvailability(snapshot);
        _availabilitySnapshotCache = snapshot;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availabilitySnapshotCache = _availabilitySnapshotCache;
      });
    }
  }

  Future<void> _setAcceptingNewPatients(bool value) async {
    if (_isSavingAvailability) {
      return;
    }

    setState(() {
      _isSavingAvailability = true;
      _acceptingNewPatientsOverride = value;
    });

    try {
      final current =
          _availabilitySnapshotCache ??
          await _bookingService.fetchMyAvailability();
      final saved = await _bookingService.saveMyAvailability(
        timezone: current.timezone,
        acceptingNewPatients: value,
        sessionDurationMinutes: current.sessionDurationMinutes,
        bufferMinutes: current.bufferMinutes,
        weeklyRules: current.weeklyRules,
        blockedDates: current.blockedDates,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availabilitySnapshotCache = saved;
        _bookingService.cacheMyAvailability(saved);
        _acceptingNewPatientsOverride = saved.acceptingNewPatients;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Your profile is open to new booking requests.'
                : 'New booking requests are paused for now.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _acceptingNewPatientsOverride = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update availability: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingAvailability = false);
      }
    }
  }

  Future<void> _openAvailabilityManager() async {
    await _warmAvailabilityCache();
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TherapistAvailabilityScreen(
          initialSnapshot: _availabilitySnapshotCache,
        ),
      ),
    );
    await _warmAvailabilityCache(force: true);
    if (mounted) {
      setState(() => _acceptingNewPatientsOverride = null);
    }
  }

  void _showPrivacyInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TherapistRadii.dialog),
        ),
        title: const Text(
          'Privacy & data access',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.headingDark,
          ),
        ),
        content: const Text(
          'Patient mood history stays private by default. You can only view data that a patient explicitly shares for care, and your public profile only appears after approval.',
          style: TextStyle(height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final confirmCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TherapistRadii.dialog),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete therapist account',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.headingDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes your therapist account, availability rules, public profile listing, appointments, therapist chat rooms, call rooms, and linked account records. This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.bodyMuted,
                height: 1.55,
              ),
            ),
            const SizedBox(height: TherapistSpacing.m),
            TextField(
              controller: confirmCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                hintText: 'DELETE',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isDeletingAccount ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isDeletingAccount
                ? null
                : () async {
                    if (confirmCtrl.text.trim() != 'DELETE') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please type DELETE to confirm.'),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    await _deleteAccount();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) {
      return;
    }

    setState(() => _isDeletingAccount = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleting therapist account...')),
    );

    try {
      await _privacyOperations.deleteMyAccount(confirmation: 'DELETE');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your therapist account has been deleted.'),
        ),
      );
      try {
        await context.read<AuthService>().signOut();
      } catch (_) {
        await FirebaseAuth.instance.signOut();
      }
    } on BackendApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code == 'recent_login_required'
                ? 'Please sign out, sign back in, and try again before deleting your account.'
                : error.message,
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final controller = context.watch<TherapistController>();

    return Stack(
      children: [
        const AppBackground(),
        StreamBuilder<TherapistProfile?>(
          stream: controller.profileStream,
          builder: (context, snapshot) {
            final profile = snapshot.data;
            final isApproved = profile?.isApproved ?? false;
            final verificationStatus =
                profile?.credentialVerificationStatus ?? 'pending_review';
            final acceptingNewPatients =
                _acceptingNewPatientsOverride ??
                profile?.acceptingNewPatients ??
                true;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: TherapistResponsiveContainer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 920;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileHero(
                            user: user,
                            profile: profile,
                            isApproved: isApproved,
                          ),
                          const SizedBox(height: TherapistSpacing.xl),
                          if (isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildVerificationSection(
                                    isApproved,
                                    verificationStatus,
                                  ),
                                ),
                                const SizedBox(width: TherapistSpacing.l),
                                Expanded(
                                  child: _buildPracticeSection(
                                    acceptingNewPatients,
                                    profile,
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _buildVerificationSection(
                              isApproved,
                              verificationStatus,
                            ),
                            const SizedBox(height: TherapistSpacing.xl),
                            _buildPracticeSection(
                              acceptingNewPatients,
                              profile,
                            ),
                          ],
                          const SizedBox(height: TherapistSpacing.xl),
                          TherapistSectionHeader(
                            icon: Icons.notifications_active_outlined,
                            title: 'Notifications & privacy',
                            subtitle:
                                'Review operational notifications, preference settings, and patient-data privacy guidance.',
                          ),
                          const SizedBox(height: TherapistSpacing.m),
                          TherapistSurfaceCard(
                            child: Column(
                              children: [
                                _ProfileActionTile(
                                  icon: Icons.notifications_active_outlined,
                                  title: 'Notification center',
                                  subtitle:
                                      'Review therapist alerts, appointment decisions, and reminder activity.',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationCenterScreen(),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 28),
                                _ProfileActionTile(
                                  icon: Icons.tune_rounded,
                                  title: 'Notification preferences',
                                  subtitle:
                                      'Control device alerts, reminders, and therapist-facing operational updates.',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationPreferencesScreen(),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 28),
                                _ProfileActionTile(
                                  icon: Icons.security_outlined,
                                  title: 'Privacy & data handling',
                                  subtitle:
                                      'Review what patient data is available and how consent limits your view.',
                                  onTap: _showPrivacyInfo,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: TherapistSpacing.xl),
                          TherapistSectionHeader(
                            icon: Icons.logout_rounded,
                            title: 'Account',
                            subtitle:
                                'Leave the therapist workspace securely when you are done.',
                          ),
                          const SizedBox(height: TherapistSpacing.m),
                          TherapistSurfaceCard(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderColor: AppColors.error.withValues(
                              alpha: 0.18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isDeletingAccount
                                        ? null
                                        : () async {
                                            await context
                                                .read<AuthService>()
                                                .signOut();
                                          },
                                    icon: const Icon(Icons.logout_rounded),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: BorderSide(
                                        color: AppColors.error.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    label: const Text('Sign out'),
                                  ),
                                ),
                                const SizedBox(height: TherapistSpacing.m),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(
                                    TherapistSpacing.m,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TherapistColors.destructiveSurface,
                                    borderRadius: BorderRadius.circular(
                                      TherapistRadii.card - 6,
                                    ),
                                    border: Border.all(
                                      color: AppColors.error.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Delete account',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.headingDark,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: TherapistSpacing.xs,
                                      ),
                                      const Text(
                                        'Permanently remove your therapist account and all linked records from MoodGenie.',
                                        style: TextStyle(
                                          height: 1.45,
                                          color: AppColors.bodyMuted,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: TherapistSpacing.m,
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: _isDeletingAccount
                                            ? null
                                            : _showDeleteAccountDialog,
                                        icon: _isDeletingAccount
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.delete_forever_rounded,
                                              ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                        ),
                                        label: Text(
                                          _isDeletingAccount
                                              ? 'Deleting...'
                                              : 'Delete therapist account',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVerificationSection(bool isApproved, String verificationStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TherapistSectionHeader(
          icon: Icons.verified_user_rounded,
          title: 'Verification & approval',
          subtitle:
              'Keep your public therapist profile accurate and compliant for patient discovery.',
        ),
        const SizedBox(height: TherapistSpacing.m),
        TherapistSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: TherapistSpacing.s,
                runSpacing: TherapistSpacing.s,
                children: [
                  TherapistStatusBadge(
                    label: isApproved
                        ? 'Approved therapist profile'
                        : 'Profile under review',
                    foreground: isApproved
                        ? AppColors.success
                        : TherapistColors.pending,
                    background: isApproved
                        ? TherapistColors.confirmedSurface
                        : TherapistColors.pendingSurface,
                    icon: isApproved
                        ? Icons.verified_rounded
                        : Icons.pending_actions_rounded,
                  ),
                  TherapistStatusBadge(
                    label: verificationStatus,
                    foreground: AppColors.primaryDeep,
                    background: AppColors.primaryFaint,
                    icon: Icons.assignment_turned_in_outlined,
                  ),
                ],
              ),
              const SizedBox(height: TherapistSpacing.m),
              Text(
                verificationStatus == 'verified'
                    ? 'Your credentials have been verified and your profile is ready to stay visible to patients.'
                    : 'Your credential file is still being reviewed. Keep your submitted details accurate and up to date.',
                style: const TextStyle(
                  height: 1.45,
                  color: AppColors.bodyMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPracticeSection(
    bool acceptingNewPatients,
    TherapistProfile? profile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TherapistSectionHeader(
          icon: Icons.health_and_safety_outlined,
          title: 'Practice settings',
          subtitle:
              'Control booking readiness, scheduling, and the public visibility of your care availability.',
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
                subtitle: Text(
                  acceptingNewPatients
                      ? 'Patients can request live slots from your published schedule.'
                      : 'Your profile stays visible, but new booking requests are paused.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                value: acceptingNewPatients,
                activeThumbColor: AppColors.primaryDeep,
                onChanged: _isSavingAvailability
                    ? null
                    : _setAcceptingNewPatients,
              ),
              const Divider(height: 28),
              _ProfileActionTile(
                icon: Icons.schedule_rounded,
                title: 'Manage availability & time slots',
                subtitle: profile?.nextAvailableAt != null
                    ? 'Next live opening ${DateFormat('EEE, MMM d • h:mm a').format(profile!.nextAvailableAt!.toLocal())}'
                    : 'Set working hours, blocked dates, buffers, and patient-facing slots.',
                onTap: _openAvailabilityManager,
              ),
              const Divider(height: 28),
              _ProfileActionTile(
                icon: Icons.person_outline_rounded,
                title: 'Edit profile details',
                subtitle:
                    'Update your public introduction, specialty details, and professional identity.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditTherapistProfileScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.user,
    required this.profile,
    required this.isApproved,
  });

  final AppUser? user;
  final TherapistProfile? profile;
  final bool isApproved;

  @override
  Widget build(BuildContext context) {
    return TherapistSummaryCard(
      title: profile?.displayName ?? user?.name ?? 'Therapist',
      subtitle: profile?.professionalTitle ?? profile?.specialty ?? 'Therapist',
      trailing: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 34),
      ),
      child: Wrap(
        spacing: TherapistSpacing.s,
        runSpacing: TherapistSpacing.s,
        children: [
          _HeroChip(icon: Icons.email_outlined, label: user?.email ?? ''),
          _HeroChip(
            icon: isApproved ? Icons.verified_rounded : Icons.pending_rounded,
            label: isApproved ? 'Approved therapist' : 'Approval in progress',
          ),
          if (profile?.nextAvailableAt != null)
            _HeroChip(
              icon: Icons.schedule_rounded,
              label:
                  'Next opening ${DateFormat('MMM d').format(profile!.nextAvailableAt!.toLocal())}',
            ),
        ],
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
        color: Colors.white.withValues(alpha: 0.15),
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

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryFaint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: AppColors.primaryDeep),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.headingDark,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: TherapistSpacing.xxs),
        child: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: AppColors.primary,
      ),
      onTap: onTap,
    );
  }
}
