import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:moodgenie/screens/home/widgets/nav_bar_item.dart';
import 'package:moodgenie/screens/home/pages/home_dashboard_page.dart';
import 'package:moodgenie/screens/home/pages/other_tabs.dart';
import 'package:moodgenie/screens/home/pages/profile_tab_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeDashboardPage(
        onNavigateToChat: () => setState(() => _currentIndex = 2),
      ),
      const MoodTabPage(),
      const ChatTabPage(),
      const ProfileTabPage(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background image fills the whole screen
          Positioned.fill(
            child: Image.asset(
              'assets/images/moodgenie_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Page content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: pages[_currentIndex],
            ),
          ),

          // Footer pinned to the bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.40),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      NavBarItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                      NavBarItem(
                        icon: Icons.emoji_emotions_outlined,
                        label: 'Mood',
                        isSelected: _currentIndex == 1,
                        onTap: () {
                          // If tapping mood, we could open log screen or just switch tab
                          // For now, switch tab
                          setState(() => _currentIndex = 1);
                        },
                      ),
                      NavBarItem(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Chat',
                        isSelected: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                      NavBarItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Profile',
                        isSelected: _currentIndex == 3,
                        onTap: () => setState(() => _currentIndex = 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
