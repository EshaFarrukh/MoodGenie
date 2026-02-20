import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../src/theme/app_theme.dart';
import '../../../models/session_model.dart';
import '../../../src/auth/models/user_model.dart';
import '../../../controllers/therapist_controller.dart';
import '../../../services/therapist_service.dart';
import '../session_management_screen.dart';

class TherapistScheduleTab extends StatelessWidget {
  const TherapistScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TherapistController>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Master Schedule',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.headingDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
             const Text(
              'Manage your upcoming sessions across all dates.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),

            // Toggle Bar Placeholder
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppShadows.soft(),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Upcoming', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDeep)),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: const Text('Past', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<List<SessionModel>>(
                stream: controller.todaySessions, // We reuse the today stream for the demo, but in reality this should be a broader query
                builder: (context, snapshot) {
                   if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  
                  final sessions = snapshot.data ?? [];
                  
                  if (sessions.isEmpty) {
                     return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 80, color: AppColors.primary.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text('Schedule Clear', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingDark)),
                          const Text('You have no upcoming confirmed sessions.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _buildMasterScheduleTile(context, session, controller);
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterScheduleTile(BuildContext context, SessionModel session, TherapistController controller) {
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
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: controller,
                  child: SessionManagementScreen(session: session),
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                   Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat('MMM').format(session.scheduledAt).toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        Text(DateFormat('d').format(session.scheduledAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryDeep)),
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
                            const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(DateFormat('h:mm a').format(session.scheduledAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accentCyan.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Confirmed', style: TextStyle(fontSize: 10, color: AppColors.accentCyan, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primary),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}
