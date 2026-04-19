import 'package:moodgenie/src/theme/app_background.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moodgenie/screens/home/pages/home_dashboard_page.dart';
import 'package:moodgenie/screens/home/pages/other_tabs.dart';
import 'package:moodgenie/screens/therapist/therapist_list_screen.dart';
import 'package:moodgenie/screens/home/widgets/shared_bottom_navigation.dart';
import 'package:moodgenie/src/notifications/app_notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppNotificationService>().maybePromptForPermission(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboardPage(
        onNavigateToChat: () => setState(() => _currentIndex = 2),
      ),
      const MoodTabPage(),
      const ChatTabPage(),
      const TherapistListScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image fills the whole screen
          Positioned.fill(child: const AppBackground()),

          // Page content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: pages[_currentIndex],
            ),
          ),

          // Footer pinned to the bottom
          SharedBottomNavigation(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() => _currentIndex = index);
            },
          ),
        ],
      ),
    );
  }
}
