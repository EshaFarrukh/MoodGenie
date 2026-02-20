import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../src/theme/app_theme.dart';
import '../../../src/auth/models/user_model.dart';
import '../../../controllers/therapist_controller.dart';
import '../therapist_user_detail_screen.dart';

class TherapistPatientsTab extends StatefulWidget {
  const TherapistPatientsTab({super.key});

  @override
  State<TherapistPatientsTab> createState() => _TherapistPatientsTabState();
}

class _TherapistPatientsTabState extends State<TherapistPatientsTab> {
  String _searchQuery = '';

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
              'Patient Directory',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.headingDark,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage and review your active patients.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Search Bar Placeholder
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppShadows.soft(),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                decoration: const InputDecoration(
                  icon: Icon(Icons.search, color: AppColors.primary),
                  hintText: 'Search patients by name...',
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: controller.assignedUsers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  
                  var users = snapshot.data ?? [];
                  
                  if (_searchQuery.isNotEmpty) {
                    users = users.where((u) => (u.name ?? 'Anonymous User').toLowerCase().contains(_searchQuery)).toList();
                  }
                  
                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 80, color: AppColors.primary.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text('No active patients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.headingDark)),
                          const Text('Patients assigned to you will appear here.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: AppShadows.soft(),
                          border: Border.all(color: AppColors.primary.withOpacity(0.05)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryDeep.withOpacity(0.2), width: 2),
                            ),
                            child: const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primaryFaint,
                              child: Icon(Icons.person, color: AppColors.primaryDeep),
                            ),
                          ),
                          title: Text(
                            user.name ?? 'Anonymous User',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.headingDark),
                          ),
                          subtitle: Text(
                            user.email,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accentCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.analytics_outlined, color: AppColors.accentCyan),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TherapistUserDetailScreen(user: user),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
