import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/therapist_controller.dart';
import '../../../src/theme/app_background.dart';
import '../../../src/theme/app_theme.dart';
import '../models/therapist_workspace_models.dart';
import '../therapist_chat_screen.dart';
import '../therapist_user_detail_screen.dart';
import '../widgets/therapist_ui.dart';

enum _PatientDirectoryFilter { all, consented, privateData }

class TherapistPatientsTab extends StatefulWidget {
  const TherapistPatientsTab({super.key});

  @override
  State<TherapistPatientsTab> createState() => _TherapistPatientsTabState();
}

class _TherapistPatientsTabState extends State<TherapistPatientsTab> {
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  _PatientDirectoryFilter _filter = _PatientDirectoryFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<TherapistController>().loadInitialPatients();
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
    context.read<TherapistController>().loadMorePatients();
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
                  List<TherapistPatientSummary> patients,
                  bool isLoading,
                  bool isLoadingMore,
                  bool hasMore,
                })
              >(
                selector: (_, value) => (
                  patients: value.patientSummaries,
                  isLoading: value.isPatientsLoading,
                  isLoadingMore: value.isLoadingMorePatients,
                  hasMore: value.hasMorePatients,
                ),
                builder: (context, state, child) {
                  final patients = _applyFilters(state.patients);
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          child: TherapistResponsiveContainer(
                            child: TherapistSectionHeader(
                              icon: Icons.people_alt_rounded,
                              title: 'Patient directory',
                              subtitle:
                                  'Review active care relationships, shared mood context, and secure follow-up actions.',
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: TherapistResponsiveContainer(
                            child: Column(
                              children: [
                                TherapistSearchBar(
                                  hintText: 'Search patients by name or email',
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value.trim().toLowerCase();
                                    });
                                  },
                                  trailing:
                                      PopupMenuButton<_PatientDirectoryFilter>(
                                        tooltip: 'Filter patients',
                                        onSelected: (value) =>
                                            setState(() => _filter = value),
                                        icon: const Icon(
                                          Icons.tune_rounded,
                                          color: AppColors.primary,
                                        ),
                                        itemBuilder: (context) => const [
                                          PopupMenuItem(
                                            value: _PatientDirectoryFilter.all,
                                            child: Text('All patients'),
                                          ),
                                          PopupMenuItem(
                                            value: _PatientDirectoryFilter
                                                .consented,
                                            child: Text('Shared mood data'),
                                          ),
                                          PopupMenuItem(
                                            value: _PatientDirectoryFilter
                                                .privateData,
                                            child: Text('Private mood data'),
                                          ),
                                        ],
                                      ),
                                ),
                                const SizedBox(height: TherapistSpacing.m),
                                _FilterChips(
                                  selected: _filter,
                                  onSelected: (value) =>
                                      setState(() => _filter = value),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (state.isLoading && state.patients.isEmpty)
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
                      else if (patients.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                            child: TherapistResponsiveContainer(
                              child: TherapistEmptyState(
                                icon: Icons.people_outline_rounded,
                                title: _searchQuery.isNotEmpty
                                    ? 'No patients match your search'
                                    : 'No active patients yet',
                                message: _searchQuery.isNotEmpty
                                    ? 'Try a different name, email, or filter to find the patient you need.'
                                    : 'Patients who confirm or complete care with you will appear here with their latest shared context.',
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
                                  final rowCount =
                                      (patients.length / itemsPerRow).ceil();

                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: rowCount,
                                    itemBuilder: (context, rowIndex) {
                                      final startIndex = rowIndex * itemsPerRow;
                                      final first = patients[startIndex];
                                      final secondIndex = startIndex + 1;
                                      final second =
                                          secondIndex < patients.length
                                          ? patients[secondIndex]
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
                                              child: _PatientCard(
                                                patient: first,
                                              ),
                                            ),
                                            if (isWide) ...[
                                              const SizedBox(
                                                width: TherapistSpacing.l,
                                              ),
                                              Expanded(
                                                child: second == null
                                                    ? const SizedBox.shrink()
                                                    : _PatientCard(
                                                        patient: second,
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
                                if (!state.hasMore && state.patients.isNotEmpty)
                                  const Text(
                                    'You’ve reached the end of the patient directory.',
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

  List<TherapistPatientSummary> _applyFilters(
    List<TherapistPatientSummary> input,
  ) {
    return input.where((patient) {
      final matchesQuery =
          _searchQuery.isEmpty ||
          (patient.user.name ?? '').toLowerCase().contains(_searchQuery) ||
          patient.user.email.toLowerCase().contains(_searchQuery);
      if (!matchesQuery) {
        return false;
      }
      switch (_filter) {
        case _PatientDirectoryFilter.all:
          return true;
        case _PatientDirectoryFilter.consented:
          return patient.hasConsent;
        case _PatientDirectoryFilter.privateData:
          return !patient.hasConsent;
      }
    }).toList();
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final TherapistPatientSummary patient;

  @override
  Widget build(BuildContext context) {
    return PatientListItem(
      summary: patient,
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
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final _PatientDirectoryFilter selected;
  final ValueChanged<_PatientDirectoryFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(
            label: 'All',
            active: selected == _PatientDirectoryFilter.all,
            onTap: () => onSelected(_PatientDirectoryFilter.all),
          ),
          const SizedBox(width: TherapistSpacing.s),
          _buildChip(
            label: 'Shared mood data',
            active: selected == _PatientDirectoryFilter.consented,
            onTap: () => onSelected(_PatientDirectoryFilter.consented),
          ),
          const SizedBox(width: TherapistSpacing.s),
          _buildChip(
            label: 'Private mood data',
            active: selected == _PatientDirectoryFilter.privateData,
            onTap: () => onSelected(_PatientDirectoryFilter.privateData),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: TherapistSpacing.s,
          vertical: TherapistSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primaryFaint
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? AppColors.primary.withValues(alpha: 0.18)
                : TherapistColors.cardBorder.withValues(alpha: 0.7),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.primaryDeep : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
