import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_realtime_media_example/main.dart';

void main() {
  testWidgets('Verify room actions and connection settings are discoverable', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChimeExampleApp());

    // Verify all three room actions are visible from the home screen.
    expect(find.text('Realtime Media'), findsOneWidget);
    expect(find.text('Join room'), findsNWidgets(2));
    expect(find.text('Create meeting'), findsOneWidget);
    expect(find.text('Start live'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await tester.tap(find.text('Create meeting').first);
    await tester.pumpAndSettle();
    expect(find.text('Create meeting'), findsNWidgets(2));

    await tester.tap(find.text('Start live').first);
    await tester.pumpAndSettle();
    expect(find.text('Start live'), findsNWidgets(2));

    // Open settings sheet
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // Verify identity and server settings in the settings sheet
    expect(find.text('Connection & Diagnostics'), findsOneWidget);
    expect(find.text('Demo identity'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    expect(find.text('Backend Service Endpoint'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    // Close settings sheet
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify back to main screen
    expect(find.text('Connection & Diagnostics'), findsNothing);
  });
}
