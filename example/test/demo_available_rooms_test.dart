import 'package:flutter/material.dart';
import 'package:multi_video/demo_available_rooms.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('available rooms lists every mode without category chips', (
    tester,
  ) async {
    var refreshed = 0;
    MediaRoomSummary? joined;
    const meeting = MediaRoomSummary(
      roomCode: '454431',
      providerId: 'livekit',
      roomMode: MediaRoomMode.meeting,
      attendeeCount: 1,
    );
    const live = MediaRoomSummary(
      roomCode: 'live-205',
      providerId: 'livekit',
      roomMode: MediaRoomMode.broadcast,
      attendeeCount: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 700,
              child: DemoAvailableRooms(
                rooms: const [meeting, live],
                error: null,
                loading: false,
                busy: false,
                onRefresh: () => refreshed++,
                onJoin: (room) => joined = room,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('可加入的房间 (2)'), findsOneWidget);
    expect(find.byType(RealtimePill), findsNothing);
    expect(find.text('454431'), findsOneWidget);
    expect(find.text('live-205'), findsOneWidget);
    await tester.tap(find.text('454431'));
    expect(joined?.roomCode, '454431');
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    expect(refreshed, 1);
    expect(tester.takeException(), isNull);
  });
}
