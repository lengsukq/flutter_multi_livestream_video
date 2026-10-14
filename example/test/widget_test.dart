import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'package:flutter_realtime_media_example/main.dart';
import 'package:flutter_realtime_media_example/demo_strings.dart';

void main() {
  testWidgets('Home keeps joining and creation reachable at every width', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ChimeExampleApp());
    for (final size in <Size>[
      Size(320, 640),
      Size(390, 844),
      Size(768, 960),
      Size(1024, 800),
      Size(1280, 900),
      Size(1440, 900),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(find.text('Realtime Media'), findsOneWidget);
      expect(find.text('Join room'), findsWidgets);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsNothing);
      expect(tester.takeException(), isNull, reason: 'Layout at $size');
    }
    await tester.ensureVisible(find.text('Create meeting').first);
    await tester.tap(find.text('Create meeting').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Create meeting'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.text('Start live').first);
    await tester.tap(find.text('Start live').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Start live'), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

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

  testWidgets('Settings is a destination and preserves the joining draft', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeExampleApp());
    await tester.pump(const Duration(milliseconds: 400));
    final roomField = find.widgetWithText(TextField, 'Room code');
    await tester.enterText(roomField, 'meeting-123');
    await tester.tap(find.text('Settings').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Demo identity'), findsOneWidget);
    expect(find.text('Backend Service Endpoint'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('meeting-123'), findsOneWidget);
    expect(find.text('Backend Service Endpoint'), findsNothing);
  });
}
