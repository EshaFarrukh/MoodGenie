import 'package:flutter/material.dart';
import 'package:moodgenie/src/theme/app_background.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../src/theme/app_theme.dart';
import '../../src/auth/services/auth_service.dart';
import '../../controllers/therapist_controller.dart';
import '../../models/session_model.dart';
import '../../src/auth/models/user_model.dart';
import 'therapist_user_detail_screen.dart';
import 'session_management_screen.dart';

class TherapistDashboardScreen extends StatelessWidget {
  const TherapistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TherapistController(),
      child: const _TherapistDashboardContent(),
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
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card(),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.medical_services, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, Dr. ${user?.name?.split(' ').first ?? 'Therapist'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                StreamBuilder<List<SessionModel>>(
                  stream: context.read<TherapistController>().todaySessions,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;
                    return Text(
                      count > 0 
                          ? 'You have $count session${count == 1 ? '' : 's'} scheduled for today.' 
                          : 'Your schedule is clear for today.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
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
      color: Colors.white.withOpacity(0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.accentSoft,
          child: const Icon(Icons.person, color: AppColors.primaryDeep),
        ),
        title: Text('Booking Request', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.headingDark)),
        subtitle: Text(timeStr),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
        onTap: () {
          final ctrl = context.read<TherapistController>();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: ctrl,
              child: SessionManagementScreen(session: session),
            ),
          ));
        },
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
    final timeStr = DateFormat('h:mm a').format(session.scheduledAt);
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.primary.withOpacity(0.2))),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat('h:mm').format(session.scheduledAt), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text(DateFormat('a').format(session.scheduledAt), style: const TextStyle(fontSize: 10, color: AppColors.primary)),
            ],
          ),
        ),
        title: const Text('Confirmed Session', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.headingDark)),
        subtitle: const Text('Click to manage or start call.', style: TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.video_call, color: AppColors.accentCyan, size: 30),
        onTap: () {
          final ctrl = context.read<TherapistController>();
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: ctrl,
              child: SessionManagementScreen(session: session),
            ),
          ));
        },
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
