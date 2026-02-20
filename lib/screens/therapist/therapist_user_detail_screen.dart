import 'package:flutter/material.dart';
import '../../src/theme/app_theme.dart';
import '../../src/theme/app_background.dart';
import '../../src/auth/models/user_model.dart';

class TherapistUserDetailScreen extends StatelessWidget {
  final AppUser user;

  const TherapistUserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Patient Details', style: TextStyle(color: AppColors.headingDark)),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 32),
                  const Text('Recent Mood History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingDark)),
                  const SizedBox(height: 16),
                  _buildMockMoodChart(),
                  const SizedBox(height: 32),
                  const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingDark)),
                  const SizedBox(height: 16),
                  _buildQuickAction(
                    icon: Icons.chat_bubble_outline,
                    title: 'Message Patient',
                    subtitle: 'Send a direct text message',
                    color: AppColors.accentCyan,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Direct therapy messaging coming soon!')));
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildQuickAction(
                    icon: Icons.description_outlined,
                    title: 'Clinical Notes',
                    subtitle: 'View your private session notes',
                    color: AppColors.primary,
                    onTap: () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clinical notes coming soon!')));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.soft(),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primaryFaint,
            child: Icon(Icons.person, size: 40, color: AppColors.primary),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? 'Anonymous',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.headingDark),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Active Patient', style: TextStyle(fontSize: 12, color: AppColors.primaryDeep, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockMoodChart() {
    // In a real implementation, this would query MoodRepository for the patient's ID
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 60, color: AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('Patient Mood Analytics', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const Text('Data locked until consent verified.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.headingDark)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
