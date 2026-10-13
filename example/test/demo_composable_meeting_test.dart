import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_example/demo_composable_meeting_page.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Demo owns meeting layout at phone, tablet and desktop sizes', (
    tester,
  ) async {
    final session = _FakeMeetingSession();
    final room = RealtimeRoom(
      media: MediaRoomSession.direct(
        roomCode: 'demo-room',
        participantId: 'self',
        session: session,
      ),
      renderer: const _FakeTrackRenderer(),
      disposeClients: () {},
    );
    addTearDown(room.dispose);

    for (final width in [390.0, 768.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 840));
      await tester.pumpWidget(
        MaterialApp(
          home: DemoComposableMeetingPage(
            room: room,
            initialSettings: const MediaLocalPreviewSettings(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(RealtimeRoomUiScope), findsOneWidget);
      expect(find.byType(RealtimeVideoGrid), findsOneWidget);
      expect(find.byType(RealtimeDockRaiseHandButton), findsOneWidget);
      expect(find.byType(RealtimeDockHandQueueButton), findsOneWidget);
      final leave = tester.getRect(find.byType(RealtimeLeaveButton));
      final page = tester.getRect(find.byType(DemoComposableMeetingPage));
      final scaffold = tester.getRect(find.byType(Scaffold).first);
      final scope = tester.getRect(find.byType(RealtimeRoomUiScope));
      final safe = tester.getRect(find.byType(SafeArea).first);
      expect(
        page.right - leave.right,
        inInclusiveRange(0, 32),
        reason:
            'surface=$width, page=$page, scaffold=$scaffold, scope=$scope, safe=$safe, leave=$leave',
      );
      expect(leave.top, lessThan(90));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}

class _FakeTrackRenderer extends MediaTrackRenderer {
  const _FakeTrackRenderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.expand();
}

class _FakeMeetingSession extends Fake implements InteractiveMediaSession {
  final MediaSnapshot _snapshot = MediaSnapshot(
    state: MediaSessionState.connected,
    capabilities: const MediaCapabilities.meeting(),
    participants: const [
      MediaParticipant(id: 'self', displayName: 'Local', isLocal: true),
    ],
  );
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => _snapshot.capabilities;
  @override
  MediaSessionState get state => _snapshot.state;
  @override
  MediaSnapshot get snapshot => _snapshot;
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();
  @override
  Stream<MediaEvent> get events => const Stream.empty();
  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() async {}
}
