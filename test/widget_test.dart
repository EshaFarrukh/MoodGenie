import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:moodgenie/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Splash screen renders branding safely without Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SplashScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('MoodGenie'), findsOneWidget);
    expect(find.text('Your AI Mental Wellness Companion'), findsOneWidget);
  });
}
