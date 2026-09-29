import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_realtime_media_example/main.dart';

void main() {
  testWidgets('Verify JoinScreen loads with tabs and settings sheet', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChimeExampleApp());

    // Verify that the provider-neutral title, tabs, and action cards are rendered on the clean main screen.
    expect(find.text('Realtime Media'), findsOneWidget);
    expect(find.text('Join room'), findsNWidgets(2));
    expect(find.text('Create room'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    // Open settings sheet
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Verify identity and server settings in the settings sheet
    expect(find.text('Server & Identity Settings'), findsOneWidget);
    expect(find.text('Demo identity'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Backend Service Endpoint'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Close settings sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify back to main screen
    expect(find.text('Server & Identity Settings'), findsNothing);
  });
}
