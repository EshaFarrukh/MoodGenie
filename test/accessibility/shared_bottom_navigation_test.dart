import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/l10n/app_localizations.dart';
import 'package:moodgenie/screens/home/widgets/shared_bottom_navigation.dart';

void main() {
  testWidgets(
    'shared bottom navigation exposes accessible labels and tap targets',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                SharedBottomNavigation(currentIndex: 0, onTap: (_) {}),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byTooltip('Home tab'), findsOneWidget);
      expect(find.byTooltip('Mood tab'), findsOneWidget);
      expect(find.byTooltip('Chat tab'), findsOneWidget);
      expect(find.byTooltip('Therapist tab'), findsOneWidget);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );
}
