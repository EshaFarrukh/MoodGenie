import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/therapist_controller.dart';
import '../../../models/session_model.dart';
import '../../../src/theme/app_background.dart';
import '../../../src/theme/app_theme.dart';
import '../models/therapist_workspace_models.dart';
import '../session_management_screen.dart';
import '../therapist_availability_screen.dart';
import '../widgets/therapist_ui.dart';

class TherapistScheduleTab extends StatefulWidget {
  const TherapistScheduleTab({super.key});

  @override
  State<TherapistScheduleTab> createState() => _TherapistScheduleTabState();
}

class _TherapistScheduleTabState extends State<TherapistScheduleTab> {
  final ScrollController _scrollController = ScrollController();
  TherapistScheduleView _view = TherapistScheduleView.today;
  TherapistScheduleStatusFilter _statusFilter =
      TherapistScheduleStatusFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<TherapistController>().loadInitialSchedule(
        view: _view,
        statusFilter: _statusFilter,
      );
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 280) {
      return;
    }
    context.read<TherapistController>().loadMoreSchedule();
  }

  Future<void> _applyScheduleFilters() {
    return context.read<TherapistController>().loadInitialSchedule(
      view: _view,
      statusFilter: _statusFilter,
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AppBackground(),
        SafeArea(
          child:
              Selector<
                TherapistController,
                ({
                  List<TherapistScheduleItem> items,
                  bool isLoading,
                  bool isLoadingMore,
                  bool hasMore,
                })
              >(
                selector: (_, value) => (
                  items: value.scheduleItems,
                  isLoading: value.isScheduleLoading,
                  isLoadingMore: value.isLoadingMoreSchedule,
                  hasMore: value.hasMoreSchedule,
                ),
                builder: (context, state, child) {
                  final items = state.items;
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: TherapistResponsiveContainer(
                            child: _ScheduleHeroCard(
                              onOpenAvailability: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TherapistAvailabilityScreen(),
                                  ),
                                );
                              },
                              hasSessions: items.isNotEmpty,
                              summary: _statusSummary(items),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TherapistResponsiveContainer(
                            child: _ScheduleControlPanel(
                              selectedView: _view,
                              selectedStatus: _statusFilter,
                              onViewChanged: (value) {
                                setState(() => _view = value);
                                _applyScheduleFilters();
                              },
                              onStatusChanged: (value) {
                                setState(() => _statusFilter = value);
                                _applyScheduleFilters();
                              },
                            ),
                          ),
                        ),
                      ),
                      if (state.isLoading && items.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                            child: TherapistResponsiveContainer(
                              child: Column(
                                children: List.generate(
                                  3,
                                  (_) => const Padding(
                                    padding: EdgeInsets.only(
                                      bottom: TherapistSpacing.m,
                                    ),
                                    child: TherapistLoadingSkeleton(
                                      lines: 4,
                                      showAvatar: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (items.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                            child: TherapistResponsiveContainer(
                              child: _ScheduleEmptyCard(
                                title: _emptyTitle(),
                                message: _emptyMessage(),
                                onManageAvailability: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const TherapistAvailabilityScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          sliver: SliverToBoxAdapter(
                            child: TherapistResponsiveContainer(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth >= 920;
                                  final itemsPerRow = isWide ? 2 : 1;
                                  final rowCount = (items.length / itemsPerRow)
                                      .ceil();

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: rowCount,
                                    itemBuilder: (context, rowIndex) {
                                      final startIndex = rowIndex * itemsPerRow;
                                      final first = items[startIndex];
                                      final secondIndex = startIndex + 1;
                                      final second = secondIndex < items.length
                                          ? items[secondIndex]
                                          : null;

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: TherapistSpacing.m,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _ScheduleCard(
                                                item: first,
                                                compact: !isWide,
                                                onOpen: () => _openSession(
                                                  context,
                                                  first.session,
                                                ),
                                              ),
                                            ),
                                            if (isWide) ...[
                                              const SizedBox(
                                                width: TherapistSpacing.l,
                                              ),
                                              Expanded(
                                                child: second == null
                                                    ? const SizedBox.shrink()
                                                    : _ScheduleCard(
                                                        item: second,
                                                        compact: false,
                                                        onOpen: () =>
                                                            _openSession(
                                                              context,
                                                              second.session,
                                                            ),
                                                      ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                          child: TherapistResponsiveContainer(
                            child: Column(
                              children: [
                                if (state.isLoadingMore)
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      bottom: TherapistSpacing.m,
                                    ),
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                if (!state.hasMore && items.isNotEmpty)
                                  const Text(
                                    'You’ve reached the end of this schedule view.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
      ],
    );
  }

  String _statusSummary(List<TherapistScheduleItem> items) {
    if (items.isEmpty) {
      return 'No sessions match the current view. Adjust the filters or open availability to refresh your live booking window.';
    }
    return '${items.length} session${items.length == 1 ? '' : 's'} in this view • ${items.where((item) => item.status == AppointmentStatus.requested).length} pending • ${items.where((item) => item.status == AppointmentStatus.confirmed).length} confirmed';
  }

  String _emptyTitle() {
    switch (_view) {
      case TherapistScheduleView.today:
        return 'No sessions scheduled today';
      case TherapistScheduleView.upcoming:
        return 'No upcoming sessions';
      case TherapistScheduleView.past:
        return 'No past session history';
    }
  }

  String _emptyMessage() {
    switch (_view) {
      case TherapistScheduleView.today:
        return 'Your confirmed sessions and pending requests for today will appear here in one organized queue.';
      case TherapistScheduleView.upcoming:
        return 'As patients request or confirm future sessions, they’ll appear here with status-aware actions.';
      case TherapistScheduleView.past:
        return 'Completed, cancelled, and older appointment records will appear here once care activity builds up.';
    }
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
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    required this.onOpen,
    this.compact = false,
  });

  final TherapistScheduleItem item;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SessionCard(
      item: item,
      onTap: onOpen,
      compact: compact,
      secondaryAction: item.status == AppointmentStatus.confirmed
          ? const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.primary,
            )
          : null,
    );
  }
}

class _ScheduleViewSwitcher extends StatelessWidget {
  const _ScheduleViewSwitcher({
    required this.selected,
    required this.onChanged,
  });

  final TherapistScheduleView selected;
  final ValueChanged<TherapistScheduleView> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ScheduleChipRow(
      children: [
        _ScheduleChip(
          label: 'Today',
          active: selected == TherapistScheduleView.today,
          onTap: () => onChanged(TherapistScheduleView.today),
        ),
        _ScheduleChip(
          label: 'Upcoming',
          active: selected == TherapistScheduleView.upcoming,
          onTap: () => onChanged(TherapistScheduleView.upcoming),
        ),
        _ScheduleChip(
          label: 'Past',
          active: selected == TherapistScheduleView.past,
          onTap: () => onChanged(TherapistScheduleView.past),
        ),
      ],
    );
  }
}

class _ScheduleStatusChips extends StatelessWidget {
  const _ScheduleStatusChips({required this.selected, required this.onChanged});

  final TherapistScheduleStatusFilter selected;
  final ValueChanged<TherapistScheduleStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ScheduleChipRow(
      children: [
        _ScheduleChip(
          label: 'All statuses',
          active: selected == TherapistScheduleStatusFilter.all,
          onTap: () => onChanged(TherapistScheduleStatusFilter.all),
        ),
        _ScheduleChip(
          label: 'Pending',
          active: selected == TherapistScheduleStatusFilter.pending,
          onTap: () => onChanged(TherapistScheduleStatusFilter.pending),
        ),
        _ScheduleChip(
          label: 'Confirmed',
          active: selected == TherapistScheduleStatusFilter.confirmed,
          onTap: () => onChanged(TherapistScheduleStatusFilter.confirmed),
        ),
        _ScheduleChip(
          label: 'Completed',
          active: selected == TherapistScheduleStatusFilter.completed,
          onTap: () => onChanged(TherapistScheduleStatusFilter.completed),
        ),
      ],
    );
  }
}

class _ScheduleChipRow extends StatelessWidget {
  const _ScheduleChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(right: TherapistSpacing.s),
        itemBuilder: (context, index) => children[index],
        separatorBuilder: (context, index) =>
            const SizedBox(width: TherapistSpacing.s),
        itemCount: children.length,
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: TherapistSpacing.m,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryDeep
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.primaryDeep
                  : TherapistColors.cardBorder.withValues(alpha: 0.9),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleHeroCard extends StatelessWidget {
  const _ScheduleHeroCard({
    required this.onOpenAvailability,
    required this.hasSessions,
    required this.summary,
  });

  final VoidCallback onOpenAvailability;
  final bool hasSessions;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      padding: const EdgeInsets.all(TherapistSpacing.l),
      color: Colors.white.withValues(alpha: 0.72),
      borderColor: Colors.white.withValues(alpha: 0.86),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final titleBlock = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: TherapistColors.cardBorder),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: TherapistSpacing.m),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Care schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.headingDark,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: TherapistSpacing.xxs),
                        Text(
                          'Review and manage today, upcoming visits, and past care activity in one organized queue.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final action = FilledButton.tonalIcon(
                onPressed: onOpenAvailability,
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.primaryDeep,
                  backgroundColor: AppColors.primaryFaint,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TherapistSpacing.m,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Availability'),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: TherapistSpacing.m),
                    action,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: TherapistSpacing.m),
                  action,
                ],
              );
            },
          ),
          if (hasSessions) ...[
            const SizedBox(height: TherapistSpacing.m),
            TherapistInfoBanner(
              title: 'Schedule summary',
              message: summary,
              icon: Icons.schedule_send_rounded,
              backgroundColor: Colors.white.withValues(alpha: 0.92),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleControlPanel extends StatelessWidget {
  const _ScheduleControlPanel({
    required this.selectedView,
    required this.selectedStatus,
    required this.onViewChanged,
    required this.onStatusChanged,
  });

  final TherapistScheduleView selectedView;
  final TherapistScheduleStatusFilter selectedStatus;
  final ValueChanged<TherapistScheduleView> onViewChanged;
  final ValueChanged<TherapistScheduleStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      padding: const EdgeInsets.all(TherapistSpacing.m),
      color: Colors.white.withValues(alpha: 0.62),
      borderColor: Colors.white.withValues(alpha: 0.84),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'View',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: TherapistSpacing.s),
          _ScheduleViewSwitcher(
            selected: selectedView,
            onChanged: onViewChanged,
          ),
          const SizedBox(height: TherapistSpacing.m),
          const Text(
            'Status',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: TherapistSpacing.s),
          _ScheduleStatusChips(
            selected: selectedStatus,
            onChanged: onStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _ScheduleEmptyCard extends StatelessWidget {
  const _ScheduleEmptyCard({
    required this.title,
    required this.message,
    required this.onManageAvailability,
  });

  final String title;
  final String message;
  final VoidCallback onManageAvailability;

  @override
  Widget build(BuildContext context) {
    return TherapistSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: TherapistSpacing.l,
        vertical: 28,
      ),
      color: Colors.white.withValues(alpha: 0.82),
      borderColor: Colors.white.withValues(alpha: 0.9),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primaryFaint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.event_note_rounded,
              color: AppColors.primaryDeep,
              size: 30,
            ),
          ),
          const SizedBox(height: TherapistSpacing.m),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: TherapistSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: TherapistSpacing.l),
          FilledButton.tonalIcon(
            onPressed: onManageAvailability,
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.primaryDeep,
              backgroundColor: AppColors.primaryFaint,
              padding: const EdgeInsets.symmetric(
                horizontal: TherapistSpacing.l,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: const Text('Manage availability'),
          ),
        ],
      ),
    );
  }
}
