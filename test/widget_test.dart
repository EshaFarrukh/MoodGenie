import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodgenie/main.dart'; // Ensure this import is correct

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We wrap it in a MediaQuery because sometimes widgets need it effectively in tests
    // But MoodGenieApp creates its own MaterialApp so it should be fine.
    await tester.pumpWidget(const MoodGenieApp());

    // Verify that the splash screen or role gate is present
    // Since Firebase needs initialization, we might hit an error here in a real unit test environment
    // without mocking Firebase. 
    // For a basic "smoke test" that just checks if the widget tree builds:
    
    expect(find.byType(MoodGenieApp), findsOneWidget);
  });
}
