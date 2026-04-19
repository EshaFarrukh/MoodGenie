import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../controllers/therapist_controller.dart';
import '../../models/session_model.dart';
import '../../src/auth/models/user_model.dart';
import '../../src/auth/services/auth_service.dart';
import '../../src/notifications/app_notification_service.dart';
import '../../src/theme/app_background.dart';
import '../../src/theme/app_theme.dart';
import 'models/therapist_workspace_models.dart';
import 'session_management_screen.dart';
import 'tabs/therapist_patients_tab.dart';
import 'tabs/therapist_profile_tab.dart';
import 'tabs/therapist_schedule_tab.dart';
import 'therapist_chat_screen.dart';
import 'therapist_user_detail_screen.dart';
import 'widgets/therapist_ui.dart';
import '../notifications/widgets/notification_bell_button.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  late int _selectedIndex;
  late final Set<int> _visitedTabs;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 3);
    _visitedTabs = <int>{_selectedIndex};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppNotificationService>().maybePromptForPermission(context);
    });
  }

  void _selectTab(int index) {
    final nextIndex = index.clamp(0, 3);
    setState(() {
      _selectedIndex = nextIndex;
      _visitedTabs.add(nextIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TherapistController(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Stack(
          children: [
            const AppBackground(),
            Stack(
              children: [
                for (final index in _visitedTabs)
                  Offstage(
                    offstage: _selectedIndex != index,
                    child: TickerMode(
                      enabled: _selectedIndex == index,
                      child: _buildTab(index),
                    ),
                  ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: _selectedIndex,
          onTap: _selectTab,
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return _TherapistDashboardContent(onSelectTab: _selectTab);
      case 1:
        return const TherapistPatientsTab();
      case 2:
        return const TherapistScheduleTab();
      case 3:
        return const TherapistProfileTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDeep.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: BottomNavigationBar(
            backgroundColor: Colors.white.withValues(alpha: 0.97),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primaryDeep,
            unselectedItemColor: AppColors.textSecondary.withValues(
              alpha: 0.58,
            ),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            currentIndex: index,
            onTap: onTap,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_customize_rounded),
                label: l10n.navHome,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.people_alt_rounded),
                label: l10n.navPatients,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month_rounded),
                label: l10n.navSchedule,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_rounded),
                label: l10n.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistDashboardContent extends StatefulWidget {
  const _TherapistDashboardContent({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  State<_TherapistDashboardContent> createState() =>
      _TherapistDashboardContentState();
}

class _TherapistDashboardContentState
    extends State<_TherapistDashboardContent> {
  DateTime? _selectedDay;

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<TherapistController>();
    final auth = context.watch<AuthService>();
    final currentUser = auth.currentUser;

    return StreamBuilder<TherapistDashboardHeader>(
      stream: controller.dashboardHeader,
      builder: (context, snapshot) {
        final dashboard = snapshot.data;
        final today = DateTime.now();
        final defaultDay = DateTime(today.year, today.month, today.day);
        final availableDays =
            dashboard?.upcomingWeek.map((day) => day.date).toList() ??
            <DateTime>[];
        if (_selectedDay == null) {
          _selectedDay = defaultDay;
        } else if (availableDays.isNotEmpty &&
            !availableDays.any((day) => _sameDay(day, _selectedDay!))) {
          _selectedDay = availableDays.first;
        }

        return Stack(
          children: [
            const AppBackground(),
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: TherapistResponsiveContainer(
                        child: StreamBuilder<TherapistProfile?>(
                          stream: controller.profileStream,
                          builder: (context, profileSnapshot) {
                            final profile = profileSnapshot.data;
                            return _DashboardTopBar(
                              currentUser: currentUser,
                              dashboard: dashboard,
                              profile: profile,
                              onSignOut: () =>
                                  context.read<AuthService>().signOut(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                      child: TherapistResponsiveContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Selector<TherapistController, TherapistUiNotice?>(
                              selector: (_, value) => value.dashboardNotice,
                              builder: (context, notice, child) {
                                if (notice == null) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: [
                                    _DashboardNoticeBanner(
                                      notice: notice,
                                      onDismiss: context
                                          .read<TherapistController>()
                                          .dismissDashboardNotice,
                                    ),
                                    const SizedBox(height: TherapistSpacing.l),
                                  ],
                                );
                              },
                            ),
                            StreamBuilder<TherapistProfile?>(
                              stream: controller.profileStream,
                              builder: (context, profileSnapshot) {
                                final profile = profileSnapshot.data;
                                return _MetricsGrid(
                                  patientCount: dashboard?.patientCount ?? 0,
                                  todayCount:
                                      dashboard?.todayConfirmedCount ?? 0,
                                  rating: profile?.rating,
                                );
                              },
                            ),
                            const SizedBox(height: TherapistSpacing.xl),
                            _buildFocusedScheduleSection(
                              context,
                              dashboard,
                              snapshot.connectionState,
                              defaultDay,
                            ),
                            if (snapshot.connectionState ==
                                    ConnectionState.waiting ||
                                (dashboard?.pendingRequests.isNotEmpty ??
                                    false)) ...[
                              const SizedBox(height: TherapistSpacing.xl),
                              _buildPendingRequestSection(
                                context,
                                dashboard,
                                snapshot.connectionState,
                              ),
                            ],
                            const SizedBox(height: TherapistSpacing.xl),
                            _DashboardSection(
                              title: 'Patients',
                              subtitle:
                                  'Recent relationships and quick actions.',
                              action: TextButton(
                                onPressed: () => widget.onSelectTab(1),
                                child: const Text('View all'),
                              ),
                              child: _PatientPreviewSection(
                                showSkeleton:
                                    dashboard == null &&
                                    snapshot.connectionState ==
                                        ConnectionState.waiting,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Selector<TherapistController, bool>(
              selector: (_, value) => value.isLoading,
              builder: (context, isLoading, child) {
                if (!isLoading) {
                  return const SizedBox.shrink();
                }
                return Container(
                  color: Colors.black.withValues(alpha: 0.16),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  List<TherapistScheduleItem> _filterSelectedDayItems(
    List<TherapistScheduleItem> items,
    DateTime selectedDay,
  ) {
    final filtered = items.where((item) {
      return _sameDay(item.startsAt, selectedDay) &&
          (item.status == AppointmentStatus.confirmed ||
              item.status == AppointmentStatus.requested);
    }).toList()..sort((left, right) => left.startsAt.compareTo(right.startsAt));
    return filtered;
  }

  Future<void> _openSession(BuildContext context, SessionModel session) async {
    final controller = context.read<TherapistController>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: SessionManagementScreen(session: session),
        ),
      ),
    );
  }

  Widget _buildPendingRequestSection(
    BuildContext context,
    TherapistDashboardHeader? dashboard,
    ConnectionState connectionState,
  ) {
    return _DashboardSection(
      title: 'Pending requests',
      subtitle: 'Review new booking requests.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashboard == null && connectionState == ConnectionState.waiting)
            const TherapistLoadingSkeleton(lines: 4, showAvatar: true)
          else if (dashboard?.pendingRequests.isEmpty ?? true)
            TherapistEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No pending requests',
              message: 'New booking requests will appear here.',
              compact: true,
            )
          else
            ...dashboard!.pendingRequests.map(
              (item) => SessionCard(
                item: item,
                compact: true,
                highlightColor: TherapistColors.pending,
                secondaryAction: TextButton(
                  onPressed: () => _openSession(context, item.session),
                  child: const Text('Review'),
                ),
                onTap: () => _openSession(context, item.session),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFocusedScheduleSection(
    BuildContext context,
    TherapistDashboardHeader? dashboard,
    ConnectionState connectionState,
    DateTime defaultDay,
  ) {
    return _DashboardSection(
      title: 'Today\'s schedule',
      subtitle: 'Review confirmed care sessions and switch days quickly.',
      action: TextButton(
        onPressed: () => widget.onSelectTab(2),
        child: const Text('Full schedule'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (dashboard == null && connectionState == ConnectionState.waiting)
            const TherapistLoadingSkeleton(lines: 2)
          else
            _WeeklyStrip(
              days: dashboard?.upcomingWeek ?? const [],
              selectedDay: _selectedDay ?? defaultDay,
              onSelect: (date) => setState(() => _selectedDay = date),
            ),
          const SizedBox(height: TherapistSpacing.m),
          if (dashboard == null && connectionState == ConnectionState.waiting)
            const TherapistLoadingSkeleton(lines: 4, showAvatar: true)
          else
            _FocusedScheduleSection(
              selectedDay: _selectedDay ?? defaultDay,
              items: _filterSelectedDayItems(
                dashboard?.scheduleItems ?? const [],
                _selectedDay ?? defaultDay,
              ),
              onOpenSession: (item) => _openSession(context, item.session),
            ),
        ],
      ),
    );
  }
}

class _PatientPreviewSection extends StatelessWidget {
  const _PatientPreviewSection({required this.showSkeleton});

  final bool showSkeleton;

  @override
  Widget build(BuildContext context) {
    return Selector<TherapistController, List<TherapistPatientSummary>>(
      selector: (_, value) => value.patientSummaries,
      builder: (context, patients, child) {
        final isLoading = context.select<TherapistController, bool>(
          (value) => value.isPatientsLoading,
        );
        if (showSkeleton && patients.isEmpty && isLoading) {
          return const TherapistLoadingSkeleton(lines: 4, showAvatar: true);
        }
        if (patients.isEmpty) {
          return TherapistEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No active patients yet',
            message: 'Confirmed care relationships will appear here.',
            compact: true,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: patients.take(4).map((patient) {
            return PatientListItem(
              summary: patient,
              compact: true,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TherapistUserDetailScreen(user: patient.user),
                ),
              ),
              onMessage: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TherapistChatScreen(
                    therapistId: patient.user.uid,
                    therapistName: patient.user.name ?? 'Patient',
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.currentUser,
    required this.dashboard,
    required this.profile,
    required this.onSignOut,
  });

  final AppUser? currentUser;
  final TherapistDashboardHeader? dashboard;
  final TherapistProfile? profile;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final todayCount = dashboard?.todayConfirmedCount ?? 0;
    final scheduleMessage = todayCount == 0
        ? 'Your schedule is clear today'
        : '$todayCount confirmed session${todayCount == 1 ? '' : 's'} today';
    final isApproved = profile?.isApproved == true;
    final displayName = _formatClinicianName(currentUser?.name);
    final roleLabel = profile?.professionalTitle?.trim().isNotEmpty == true
        ? profile!.professionalTitle!.trim()
        : profile?.specialty?.trim().isNotEmpty == true
        ? profile!.specialty!.trim()
        : 'Therapist';

    return GradientCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          TherapistColors.headerDeep.withValues(alpha: 0.96),
          TherapistColors.headerBottom.withValues(alpha: 0.94),
          AppColors.primarySoft.withValues(alpha: 0.92),
        ],
      ),
      borderColor: Colors.white.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                    const SizedBox(width: TherapistSpacing.xs),
                    Text(
                      DateFormat('EEEE, d MMMM').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TherapistSpacing.m),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const NotificationBellButton(
                    iconColor: Colors.white,
                    backgroundColor: Color(0x26FFFFFF),
                  ),
                  const SizedBox(width: TherapistSpacing.s),
                  _HeaderActionButton(
                    icon: Icons.logout_rounded,
                    tooltip: AppLocalizations.of(context)!.signOut,
                    onTap: onSignOut,
                    iconColor: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: TherapistSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              return Container(
                padding: const EdgeInsets.all(TherapistSpacing.m),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(TherapistRadii.card),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.74),
                  ),
                  boxShadow: AppShadows.card(color: AppColors.primaryDeep),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: TherapistSpacing.s,
                      runSpacing: TherapistSpacing.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TherapistSpacing.s,
                            vertical: TherapistSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFaint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Clinician Dashboard',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                        TherapistStatusBadge(
                          label: isApproved ? 'Approved' : 'In review',
                          foreground: isApproved
                              ? AppColors.success
                              : TherapistColors.pending,
                          background: isApproved
                              ? TherapistColors.confirmedSurface
                              : TherapistColors.pendingSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: TherapistSpacing.m),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isCompact ? 48 : 56,
                          height: isCompact ? 48 : 56,
                          decoration: BoxDecoration(
                            color: AppColors.primaryFaint,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.medical_services_rounded,
                            color: AppColors.primaryDeep,
                            size: isCompact ? 22 : 26,
                          ),
                        ),
                        const SizedBox(width: TherapistSpacing.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: isCompact ? 25 : 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.7,
                                  color: AppColors.headingDark,
                                  height: 1.05,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: TherapistSpacing.xxs),
                              Text(
                                roleLabel,
                                style: TextStyle(
                                  fontSize: isCompact ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: TherapistSpacing.m),
          TherapistInfoBanner(
            icon: Icons.event_available_rounded,
            title: scheduleMessage,
            backgroundColor: Colors.white.withValues(alpha: 0.96),
          ),
        ],
      ),
    );
  }

  String _formatClinicianName(String? rawName) {
    final name = rawName?.trim();
    if (name == null || name.isEmpty) {
      return 'Therapist';
    }

    final withoutPrefix = name.replaceFirst(
      RegExp(r'^dr\.?\s*', caseSensitive: false),
      '',
    );
    final words = withoutPrefix
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');

    if (words.isEmpty) {
      return 'Therapist';
    }

    return 'Dr. $words';
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle, action: action),
        const SizedBox(height: TherapistSpacing.m),
        child,
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor = AppColors.primaryDeep,
    this.backgroundColor = AppColors.primaryFaint,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onTap;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _DashboardNoticeBanner extends StatelessWidget {
  const _DashboardNoticeBanner({required this.notice, required this.onDismiss});

  final TherapistUiNotice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final background = notice.isError
        ? TherapistColors.destructiveSurface
        : AppColors.primaryFaint;
    final foreground = notice.isError ? AppColors.error : AppColors.primaryDeep;
    return TherapistSurfaceCard(
      color: background,
      borderColor: foreground.withValues(alpha: 0.18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(notice.icon, color: foreground),
          ),
          const SizedBox(width: TherapistSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (notice.title != null)
                  Text(
                    notice.title!,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: foreground,
                    ),
                  ),
                if (notice.title != null)
                  const SizedBox(height: TherapistSpacing.xxs),
                Text(
                  notice.message,
                  style: const TextStyle(
                    height: 1.45,
                    color: AppColors.bodyMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.patientCount,
    required this.todayCount,
    required this.rating,
  });

  final int patientCount;
  final int todayCount;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final cards = [
      DashboardMetricCard(
        value: patientCount.toString(),
        label: 'Patients',
        icon: Icons.people_alt_rounded,
        accent: AppColors.accentCyan,
      ),
      DashboardMetricCard(
        value: todayCount.toString(),
        label: 'Today',
        icon: Icons.calendar_today_rounded,
        accent: AppColors.primary,
      ),
      DashboardMetricCard(
        value: rating?.toStringAsFixed(1) ?? 'New',
        label: 'Rating',
        icon: Icons.star_rounded,
        accent: const Color(0xFFF4B400),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: TherapistSpacing.s),
                    child: card,
                  ),
                )
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              Expanded(child: cards[index]),
              if (index != cards.length - 1)
                const SizedBox(width: TherapistSpacing.s),
            ],
          ],
        );
      },
    );
  }
}

class _WeeklyStrip extends StatelessWidget {
  const _WeeklyStrip({
    required this.days,
    required this.selectedDay,
    required this.onSelect,
  });

  final List<TherapistDayOverview> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return TherapistEmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'No schedule data yet',
        message: 'Your week overview will appear once sessions are booked.',
      );
    }

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (context, _) =>
            const SizedBox(width: TherapistSpacing.s),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = _sameDay(day.date, selectedDay);
          final isToday = _sameDay(day.date, DateTime.now());
          return DaySelector(
            day: day,
            isSelected: isSelected,
            isToday: isToday,
            onTap: () => onSelect(day.date),
          );
        },
      ),
    );
  }
}

class _FocusedScheduleSection extends StatelessWidget {
  const _FocusedScheduleSection({
    required this.selectedDay,
    required this.items,
    required this.onOpenSession,
  });

  final DateTime selectedDay;
  final List<TherapistScheduleItem> items;
  final ValueChanged<TherapistScheduleItem> onOpenSession;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return TherapistEmptyState(
        icon: Icons.event_busy_rounded,
        title:
            'No confirmed sessions on ${DateFormat('MMM d').format(selectedDay)}',
        message: 'Review pending requests or open your full schedule.',
        compact: true,
      );
    }

    return Column(
      children: items
          .map(
            (item) => SessionCard(
              item: item,
              compact: true,
              onTap: () => onOpenSession(item),
            ),
          )
          .toList(),
    );
  }
}
