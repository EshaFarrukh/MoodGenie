import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../src/theme/app_theme.dart';
import '../../src/auth/services/auth_service.dart';
import '../../controllers/therapist_controller.dart';
import '../../models/session_model.dart';
import '../../src/auth/models/user_model.dart';
import '../../services/therapist_service.dart';
import 'therapist_user_detail_screen.dart';
import 'session_management_screen.dart';
import 'tabs/therapist_patients_tab.dart';
import 'tabs/therapist_schedule_tab.dart';
import 'tabs/therapist_profile_tab.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() => _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  int _selectedIndex = 0;

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
            IndexedStack(
              index: _selectedIndex,
              children: [
                const _TherapistDashboardContent(),
                const TherapistPatientsTab(),
                const TherapistScheduleTab(),
                const TherapistProfileTab(),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: AppColors.primaryDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: BottomNavigationBar(
            backgroundColor: Colors.white.withOpacity(0.9),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primaryDeep,
            unselectedItemColor: AppColors.textSecondary.withOpacity(0.5),
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Patients'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Schedule'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistDashboardContent extends StatelessWidget {
  const _TherapistDashboardContent();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TherapistController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildWelcomeCard(context),
                      const SizedBox(height: 24),
                      _buildWeeklyCalendar(context),
                      const SizedBox(height: 24),
                      _buildMetricsRow(context, controller),
                      const SizedBox(height: 24),
                      if (controller.error != null) _buildErrorBanner(controller.error!),
                      _buildPendingRequestsSection(context, controller),
                      const SizedBox(height: 24),
                      _buildTodaySessionsSection(context, controller),
                      const SizedBox(height: 24),
                      _buildAssignedUsersSection(context, controller),
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          if (controller.isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 80,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
          boxShadow: AppShadows.soft(),
        ),
        child: FlexibleSpaceBar(
          title: const Text(
            'Doctor Dashboard',
            style: TextStyle(
              color: AppColors.headingDark,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
      ),
      actions: [
        IconButton(
          onPressed: () async {
            await context.read<AuthService>().signOut();
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.primary),
          tooltip: 'Sign Out',
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryDeep,
        image: const DecorationImage(
          image: NetworkImage('https://www.transparenttextures.com/patterns/cubes.png'),
          opacity: 0.1,
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppColors.primaryDeep.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.transparent,
                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${user?.name?.split(' ').first ?? 'Therapist'}',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    Text(
                      'Clinical Psychologist',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                 child: const Icon(Icons.notifications_none, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<List<SessionModel>>(
                    stream: context.read<TherapistController>().todaySessions,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      return Text(
                        count > 0 
                            ? 'You have $count session${count == 1 ? '' : 's'} scheduled for today.' 
                            : 'Your schedule is clear for today.',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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

  Widget _buildWeeklyCalendar(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcomingDates = List.generate(7, (i) => today.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Weekly Overview', Icons.calendar_month),
        const SizedBox(height: 12),
        SizedBox(
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: upcomingDates.length,
            separatorBuilder: (context, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final date = upcomingDates[index];
              final isToday = index == 0;
              final dayName = DateFormat('EEE').format(date);
              final dayNum = DateFormat('d').format(date);

              return Container(
                width: 65,
                decoration: BoxDecoration(
                  gradient: isToday
                      ? const LinearGradient(colors: [AppColors.primary, AppColors.accentCyan], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: isToday ? null : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: isToday ? null : Border.all(color: AppColors.primary.withOpacity(0.1)),
                  boxShadow: isToday ? [BoxShadow(color: AppColors.accentCyan.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isToday ? Colors.white : AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(dayNum, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isToday ? Colors.white : AppColors.headingDark)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(BuildContext context, TherapistController controller) {
    return Row(
      children: [
        Expanded(child: _buildMetricCard(context, 'Total Patients', Icons.people_alt, AppColors.accentCyan)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(context, 'Telehealth', Icons.video_call, AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(child: _buildMetricCard(context, 'Rating', Icons.star, Colors.amber)),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft(),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.headingDark), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection(BuildContext context, TherapistController controller) {
    return StreamBuilder<List<SessionModel>>(
      stream: controller.pendingRequests,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Hide if empty
        }
        final requests = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Pending Approvals', Icons.notifications_active),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final session = requests[index];
                return _buildPendingTile(context, session);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingTile(BuildContext context, SessionModel session) {
    final timeStr = DateFormat('MMM d, h:mm a').format(session.scheduledAt);
    return Card(
      elevation: 0,
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.05),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.orange.withOpacity(0.2), width: 1.5)),
      margin: const EdgeInsets.only(bottom: 16),
      child: FutureBuilder<AppUser?>(
        future: TherapistService().getUserById(session.userId),
        builder: (context, snapshot) {
          final userName = snapshot.data?.name ?? 'Loading Patient...';
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              final ctrl = context.read<TherapistController>();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: ctrl,
                  child: SessionManagementScreen(session: session),
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.person, color: Colors.orange),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pending: $userName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.headingDark)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(timeStr, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.orange),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildTodaySessionsSection(BuildContext context, TherapistController controller) {
    return StreamBuilder<List<SessionModel>>(
      stream: controller.todaySessions,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final sessions = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Today\'s Schedule', Icons.calendar_today),
            const SizedBox(height: 12),
            if (sessions.isEmpty)
              _buildEmptyState('No sessions scheduled for today yet!')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  return _buildSessionTile(context, sessions[index]);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildSessionTile(BuildContext context, SessionModel session) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shadowColor: AppColors.primary.withOpacity(0.1),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.primary.withOpacity(0.15), width: 1.5)),
      margin: const EdgeInsets.only(bottom: 16),
      child: FutureBuilder<AppUser?>(
        future: TherapistService().getUserById(session.userId),
        builder: (context, snapshot) {
          final userName = snapshot.data?.name ?? 'Loading...';
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              final ctrl = context.read<TherapistController>();
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: ctrl,
                  child: SessionManagementScreen(session: session),
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('h:mm').format(session.scheduledAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDeep)),
                        Text(DateFormat('a').format(session.scheduledAt), style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.headingDark)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Confirmed', style: TextStyle(fontSize: 10, color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            const Text('Video Call', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.video_camera_front, color: AppColors.primary, size: 24),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildAssignedUsersSection(BuildContext context, TherapistController controller) {
    return StreamBuilder<List<AppUser>>(
      stream: controller.assignedUsers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        final users = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Your Patients', Icons.people_alt),
            const SizedBox(height: 12),
            if (users.isEmpty)
              _buildEmptyState('No patients assigned yet.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final u = users[index];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: AppColors.primaryFaint, child: Icon(Icons.person, color: AppColors.primary)),
                      title: Text(u.name ?? 'Anonymous User', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(u.email, style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      onTap: () {
                         Navigator.push(context, MaterialPageRoute(
                          builder: (_) => TherapistUserDetailScreen(user: u),
                        ));
                      },
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryDeep, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.headingDark,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
