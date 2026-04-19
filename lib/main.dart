import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'firebase_options.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/therapist/therapist_dashboard_screen.dart';
import 'src/theme/app_theme.dart';
import 'src/auth/auth_di.dart';
import 'src/auth/widgets/auth_widgets.dart';
import 'src/navigation/app_navigator.dart';
import 'src/notifications/app_notification_service.dart';
import 'src/services/app_telemetry_service.dart';
import 'src/services/mood_repository.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebase();
}

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _reportUnhandledError(
          details.exception,
          details.stack ?? StackTrace.current,
          source: 'FlutterError',
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        _reportUnhandledError(error, stack, source: 'PlatformDispatcher');
        return true;
      };

      await _initializeFirebase();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      runApp(const MoodGenieApp());
    },
    (error, stack) {
      _reportUnhandledError(error, stack, source: 'runZonedGuarded');
    },
  );
}

Future<void> _initializeFirebase() async {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return;
  }

  await Firebase.initializeApp();
}

void _reportUnhandledError(
  Object error,
  StackTrace stack, {
  required String source,
}) {
  if (kDebugMode) {
    debugPrint('[$source] Unhandled ${error.runtimeType}');
    debugPrintStack(stackTrace: stack);
  }
  unawaited(
    AppTelemetryService.instance.captureError(
      error,
      stack,
      source: source,
      fatal: true,
    ),
  );
}

class MoodGenieApp extends StatelessWidget {
  const MoodGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthDependencyInjection.authService,
        ),
        ChangeNotifierProvider(
          create: (_) => AppNotificationService()..initialize(),
        ),
        Provider(create: (_) => MoodRepository()),
      ],
      child: MaterialApp(
        title: 'MoodGenie',
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        theme: AppTheme.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoleGate(
          userHome: const HomeScreen(),
          therapistDashboard: const TherapistDashboardScreen(),
          roleSelectionScreen: const RoleSelectionScreen(),
          splashScreen: const SplashScreen(),
        ),
      ),
    );
  }
}
