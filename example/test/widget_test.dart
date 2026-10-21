import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

import 'package:flutter_realtime_media_example/main.dart';
import 'package:flutter_realtime_media_example/demo_strings.dart';

void main() {
  testWidgets('Home creation cards align heights and button bottoms', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ChimeExampleApp());

    for (final viewport in [const Size(760, 900), const Size(1280, 900)]) {
      tester.view.physicalSize = viewport;
      await tester.pump(const Duration(milliseconds: 400));
      final meeting = find.byKey(const ValueKey('demo-create-meeting'));
      final live = find.byKey(const ValueKey('demo-start-live'));
      final meetingRect = tester.getRect(meeting);
      final liveRect = tester.getRect(live);
      expect(
        meetingRect.top,
        closeTo(liveRect.top, 1),
        reason: 'Card tops differ at $viewport',
      );
      expect(
        meetingRect.bottom,
        closeTo(liveRect.bottom, 1),
        reason: 'Card bottoms differ at $viewport',
      );
      final meetingAction = find.descendant(
        of: meeting,
        matching: find.byType(OutlinedButton),
      );
      final liveAction = find.descendant(
        of: live,
        matching: find.byType(OutlinedButton),
      );
      expect(meetingAction, findsOneWidget);
      expect(liveAction, findsOneWidget);
      expect(
        tester.getRect(meetingAction).bottom,
        closeTo(tester.getRect(liveAction).bottom, 1),
        reason: 'Creation buttons do not align at $viewport',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('header language control switches English and Chinese on tap', (
    tester,
  ) async {
    await tester.pumpWidget(const ChimeExampleApp());
    await tester.pump(const Duration(milliseconds: 400));
    final languageToggle = find.byKey(const ValueKey('demo-toggle-language'));
    expect(languageToggle, findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('QUICK JOIN'), findsOneWidget);
    expect(find.byType(PopupMenuButton<Locale>), findsNothing);

    await tester.tap(languageToggle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('中'), findsOneWidget);
    expect(find.text('快速加入'), findsOneWidget);

    await tester.tap(languageToggle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('EN'), findsOneWidget);
    expect(find.text('QUICK JOIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home has no duplicate create actions inside the join card', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const ChimeExampleApp());
    await tester.pump(const Duration(milliseconds: 450));

    final joinCard = find.byKey(const ValueKey('demo-join-card'));
    expect(joinCard, findsOneWidget);
    expect(find.byKey(const ValueKey('demo-create-meeting')), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-start-live')), findsOneWidget);
    expect(
      find.descendant(of: joinCard, matching: find.text('Create meeting')),
      findsNothing,
    );
    expect(
      find.descendant(of: joinCard, matching: find.text('Start live')),
      findsNothing,
    );
    expect(find.text('Create meeting'), findsOneWidget);
    expect(find.text('Start live'), findsOneWidget);
    expect(find.text('QUICK JOIN'), findsOneWidget);
    expect(find.text('Tandem'), findsNothing);
    expect(find.text('Realtime Media'), findsOneWidget);

    final header = tester.getRect(
      find.byKey(const ValueKey('demo-main-header')),
    );
    final hero = tester.getRect(find.byKey(const ValueKey('demo-home-hero')));
    expect(header.height, inInclusiveRange(60, 90));
    expect(hero.top, greaterThanOrEqualTo(header.bottom));
    expect(tester.takeException(), isNull);
  });

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
    await tester.tap(
      (find
              .byKey(const ValueKey('realtime-destination-2'))
              .evaluate()
              .isNotEmpty
          ? find.byKey(const ValueKey('realtime-destination-2'))
          : find.text('Settings').last),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Demo identity'), findsOneWidget);
    expect(find.text('Backend Service Endpoint'), findsOneWidget);
    expect(find.text('Display name'), findsOneWidget);
    await tester.tap(
      (find
              .byKey(const ValueKey('realtime-destination-0'))
              .evaluate()
              .isNotEmpty
          ? find.byKey(const ValueKey('realtime-destination-0'))
          : find.text('Home').last),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('meeting-123'), findsOneWidget);
    expect(find.text('Backend Service Endpoint'), findsNothing);
  });
}
