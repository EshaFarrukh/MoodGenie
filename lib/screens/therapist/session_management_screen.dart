import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../src/theme/app_theme.dart';
import '../../src/theme/app_background.dart';
import '../../models/session_model.dart';
import '../../controllers/therapist_controller.dart';
import 'video_call_screen.dart';

class SessionManagementScreen extends StatelessWidget {
  final SessionModel session;

  const SessionManagementScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    // We instantiate a proxy to call the provider safely without losing context
    final controller = context.read<TherapistController>();
    final isPending = session.status == 'pending';
    final isAccepted = session.status == 'accepted';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Session Details', style: TextStyle(color: AppColors.headingDark)),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSessionInfoCard(),
                  const SizedBox(height: 32),
                  
                  if (isPending) ...[
                    const Text('Action Required', style: TextStyle(fontSize: 18, fontWeight: bold, color: AppColors.headingDark)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await controller.rejectSession(session.sessionId);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              await controller.acceptSession(session.sessionId);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Accept Booking'),
                          ),
                        ),
                      ],
                    ),
                  ],

                  if (isAccepted) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        try {
                          final roomId = await controller.startVideoSession(session.sessionId);
                          if (context.mounted) {
                            Navigator.pushReplacement(context, MaterialPageRoute(
                              builder: (_) => VideoCallScreen(roomId: roomId, isTherapist: true),
                            ));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
                      icon: const Icon(Icons.video_camera_front),
                      label: const Text('Start Video Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryDeep),
                      onPressed: () async {
                        await controller.markSessionCompleted(session.sessionId);
                         if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark as Completed'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          Consumer<TherapistController>(
            builder: (context, ctrl, child) {
              if (ctrl.isLoading) {
                return Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status', style: TextStyle(color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: session.status == 'pending' ? Colors.orange.shade100 : 
                         session.status == 'accepted' ? Colors.green.shade100 : AppColors.primaryFaint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  session.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: session.status == 'pending' ? Colors.orange.shade800 :
                           session.status == 'accepted' ? Colors.green.shade800 : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow(Icons.calendar_today, 'Date', dateFormat.format(session.scheduledAt)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.access_time, 'Time', timeFormat.format(session.scheduledAt)),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person_outline, 'Patient ID', session.userId.substring(0, 8) + '...'), // In a real app, fetch patient name
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingDark)),
          ],
        ),
      ],
    );
  }
}

const bold = FontWeight.bold;
