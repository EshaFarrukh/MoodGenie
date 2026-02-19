import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/therapist/therapist_dashboard_screen.dart';
import 'src/theme/app_theme.dart';
import 'src/auth/auth_di.dart';
import 'src/auth/widgets/auth_widgets.dart';
import 'src/services/mood_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MoodGenieApp());
}

class MoodGenieApp extends StatelessWidget {
  const MoodGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthDependencyInjection.authService),
        Provider(create: (_) => MoodRepository()),
      ],
      child: MaterialApp(
        title: 'MoodGenie',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: RoleGate(
          userHome: const HomeScreen(),
          therapistDashboard: const TherapistDashboardScreen(),
          loginScreen: const LoginScreen(),
          splashScreen: const SplashScreen(),
        ),
      ),
    );
  }
}
