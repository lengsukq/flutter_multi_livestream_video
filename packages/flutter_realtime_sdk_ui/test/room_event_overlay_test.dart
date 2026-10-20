import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'support/meeting_sharing_fixture.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'bubbles fit a low viewport with large text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 240));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final fixture = await MeetingSharingFixture.create();
        addTearDown(fixture.room.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? ThemeData.dark() : RealtimeUiTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 240),
                textScaler: TextScaler.linear(2),
              ),
              child: RealtimeRoomUiScope(
                room: fixture.room,
                child: Scaffold(
                  body: SizedBox(
                    height: 80,
                    child: RealtimeRoomEventOverlay(room: fixture.room),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final name in [
          'First participant with a long name',
          'Second participant with a long name',
          'Third participant with a long name',
        ]) {
          fixture.media.eventChanges.add(
            MediaParticipantJoined(
              MediaParticipant(id: name, displayName: name),
            ),
          );
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(SingleChildScrollView)).height,
          lessThanOrEqualTo(80),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'room events are bounded, coalesced, expire and stop after disposal',
    (tester) async {
      final fixture = await MeetingSharingFixture.create();
      addTearDown(fixture.room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeRoomUiScope(
            room: fixture.room,
            child: Scaffold(body: RealtimeRoomEventOverlay(room: fixture.room)),
          ),
        ),
      );
      void joined(String name) => fixture.media.eventChanges.add(
        MediaParticipantJoined(MediaParticipant(id: name, displayName: name)),
      );
      for (final name in ['A', 'B', 'C', 'C', 'D']) {
        joined(name);
      }
      await tester.pump();
      expect(find.text('A joined'), findsNothing);
      for (final name in ['B', 'C', 'D']) {
        expect(find.text('$name joined'), findsOneWidget);
      }
      await tester.pump(const Duration(seconds: 6));
      expect(find.byType(Card), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      joined('After disposal');
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reconnection stays visible and recovery is acknowledged once', (
    tester,
  ) async {
    final fixture = await MeetingSharingFixture.create();
    addTearDown(fixture.room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: fixture.room,
          child: Scaffold(body: RealtimeRoomEventOverlay(room: fixture.room)),
        ),
      ),
    );
    void connection(MediaSessionState previous, MediaSessionState current) {
      fixture.media.emit(fixture.media.current.copyWith(state: current));
      fixture.media.eventChanges.add(
        MediaConnectionStateChanged(previous: previous, current: current),
      );
    }

    connection(MediaSessionState.connected, MediaSessionState.reconnecting);
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Connection lost. Reconnecting…'), findsOneWidget);
    connection(MediaSessionState.reconnecting, MediaSessionState.connected);
    await tester.pumpAndSettle();
    expect(find.text('Connection lost. Reconnecting…'), findsNothing);
    expect(find.text('Connection restored'), findsOneWidget);
    connection(MediaSessionState.connected, MediaSessionState.ended);
    await tester.pumpAndSettle();
    expect(find.text('This session has ended'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
