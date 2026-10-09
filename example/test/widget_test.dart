import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'package:flutter_realtime_media_example/main.dart';
import 'package:flutter_realtime_media_example/demo_strings.dart';

void main() {
  testWidgets(
    'Home keeps room actions accessible at phone, tablet and desktop sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const ChimeExampleApp());
      for (final size in <Size>[
        const Size(320, 640),
        const Size(390, 844),
        const Size(768, 960),
        const Size(1200, 800),
        const Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(
          find.text('Realtime Media'),
          findsOneWidget,
          reason: 'Missing brand at $size',
        );
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
        expect(find.text('Join room'), findsWidgets);
        if (size.width < 600) {
          expect(
            find.text('REALTIME WORKSPACE'),
            findsNothing,
            reason: 'Large marketing hero must be hidden on phones at $size',
          );
          expect(
            tester.getTopLeft(find.text('Join room').first).dy,
            lessThan(450),
            reason: 'Join entry should remain near the first screen at $size',
          );
        } else {
          expect(
            find.text('REALTIME WORKSPACE'),
            findsOneWidget,
            reason: 'Keep the full hero on tablets and desktop at $size',
          );
        }
        expect(
          tester.takeException(),
          isNull,
          reason: 'Layout overflow at $size',
        );
      }
      await tester.ensureVisible(find.text('Create meeting').first);
      await tester.pump();
      await tester.tap(find.text('Create meeting').first);
      await tester.pumpAndSettle();
      expect(find.text('Create meeting'), findsWidgets);
      await tester.ensureVisible(find.text('Start live').first);
      await tester.pump();
      await tester.tap(find.text('Start live').first);
      await tester.pumpAndSettle();
      expect(find.text('Start live'), findsWidgets);
    },
  );

  testWidgets('Demo renders SDK errors with recovery guidance', (
    WidgetTester tester,
  ) async {
    const failure = RealtimeException(
      code: RealtimeErrorCode.network,
      message: 'Unable to reach the room.',
      providerId: 'livekit',
      suggestedAction: 'retry',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) =>
              Text(DemoStrings.of(context).displayRealtimeError(failure)),
        ),
      ),
    );
    expect(find.textContaining('Unable to reach the room.'), findsOneWidget);
    expect(find.textContaining('Provider: livekit'), findsOneWidget);
    expect(find.textContaining('Please retry.'), findsOneWidget);
  });

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

    await tester.ensureVisible(find.text('Create meeting').first);
    await tester.pump();
    await tester.tap(find.text('Create meeting').first);
    await tester.pumpAndSettle();
    expect(find.text('Create meeting'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Start live').first);
    await tester.pump();
    await tester.tap(find.text('Start live').first);
    await tester.pumpAndSettle();
    expect(find.text('Start live'), findsNWidgets(2));

    // Open settings sheet
    await tester.ensureVisible(find.byIcon(Icons.settings_outlined));
    await tester.pump();
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
