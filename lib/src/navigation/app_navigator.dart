import 'package:flutter/material.dart';
import 'package:moodgenie/screens/mood/mood_history_screen.dart';
import 'package:moodgenie/screens/mood/mood_log_screen.dart';
import 'package:moodgenie/screens/notifications/notification_center_screen.dart';
import 'package:moodgenie/screens/therapist/my_therapy_requests_screen.dart';
import 'package:moodgenie/screens/therapist/therapist_dashboard_screen.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void handleNotificationDeepLink(String? deepLink) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null || deepLink == null || deepLink.trim().isEmpty) {
    return;
  }

  final uri = Uri.tryParse(deepLink.trim());
  if (uri == null) {
    return;
  }

  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments;

  Widget? destination;

  if (host == 'mood' && segments.isNotEmpty && segments.first == 'log') {
    destination = const MoodLogScreen();
  } else if (host == 'mood' &&
      segments.isNotEmpty &&
      segments.first == 'history') {
    destination = const MoodHistoryScreen();
  } else if (host == 'appointments') {
    final role = uri.queryParameters['role']?.trim().toLowerCase();
    destination = role == 'therapist'
        ? const TherapistDashboardScreen(initialIndex: 0)
        : const MyTherapyRequestsScreen();
  } else if (host == 'therapist' &&
      segments.isNotEmpty &&
      segments.first == 'requests') {
    destination = const TherapistDashboardScreen(initialIndex: 0);
  } else if (host == 'notifications') {
    destination = const NotificationCenterScreen();
  }

  if (destination == null) {
    return;
  }

  navigator.push(MaterialPageRoute(builder: (_) => destination!));
}
