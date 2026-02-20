import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../src/theme/app_theme.dart';
import '../../../src/auth/services/auth_service.dart';

class TherapistProfileTab extends StatefulWidget {
  const TherapistProfileTab({super.key});

  @override
  State<TherapistProfileTab> createState() => _TherapistProfileTabState();
}

class _TherapistProfileTabState extends State<TherapistProfileTab> {
  bool _isAcceptingNewPatients = true;
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryDeep.withOpacity(0.2), width: 4),
                      boxShadow: [
                        BoxShadow(color: AppColors.primaryDeep.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                  ),
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 60, color: AppColors.primaryDeep),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dr. ${user?.name ?? 'Therapist'}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.headingDark, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text('Clinical Psychologist', style: TextStyle(fontSize: 16, color: AppColors.primaryDeep, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Availability Settings
            _buildSectionHeader('Availability'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.soft(),
              ),
              child: SwitchListTile(
                title: const Text('Accepting New Patients', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.headingDark)),
                subtitle: const Text('Allow new users to request bookings', style: TextStyle(fontSize: 12)),
                activeColor: AppColors.primaryDeep,
                value: _isAcceptingNewPatients,
                onChanged: (val) => setState(() => _isAcceptingNewPatients = val),
              ),
            ),
            const SizedBox(height: 24),

            // General Settings
             _buildSectionHeader('General Settings'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.soft(),
              ),
              child: Column(
                children: [
                  _buildListTile(Icons.person_outline, 'Edit Profile Details', onTap: () {}),
                  const Divider(height: 1, thickness: 1, color: AppColors.primaryLight, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.headingDark)),
                    activeColor: AppColors.primaryDeep,
                    value: _notificationsEnabled,
                    onChanged: (val) => setState(() => _notificationsEnabled = val),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: AppColors.primaryLight, indent: 16, endIndent: 16),
                  _buildListTile(Icons.security, 'Privacy & Security', onTap: () {}),
                  const Divider(height: 1, thickness: 1, color: AppColors.primaryLight, indent: 16, endIndent: 16),
                  _buildListTile(Icons.help_outline, 'Help & Support', onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () async {
                   await context.read<AuthService>().signOut();
                },
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 100), // padding for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2),
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, {VoidCallback? onTap, Color? color}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color ?? AppColors.primary),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? AppColors.headingDark)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
