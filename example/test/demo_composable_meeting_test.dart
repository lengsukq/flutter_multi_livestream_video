import 'support/design_capture.dart';
import 'package:flutter/material.dart';
import 'package:multi_video/demo_composable_meeting_page.dart';
import 'package:multi_video/demo_meeting_room_page.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDesignCapture);
  test(
    'server room mode beats guest prejoin selection after connection',
    () async {
      final meeting = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'm',
          participantId: 'guest',
          session: _FakeMeetingSession(),
          backendMetadata: const {'roomMode': 'meeting'},
        ),
        renderer: const _FakeTrackRenderer(),
        disposeClients: () {},
      );
      final broadcast = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'l',
          participantId: 'guest',
          session: _FakeMeetingSession(),
          backendMetadata: const {'roomMode': 'broadcast'},
        ),
        renderer: const _FakeTrackRenderer(),
        disposeClients: () {},
      );
      final plain = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'fallback',
          participantId: 'guest',
          session: _FakeMeetingSession(),
        ),
        renderer: const _FakeTrackRenderer(),
        disposeClients: () {},
      );
      expect(MeetingRoomPage.isLiveSession(meeting), isFalse);
      expect(MeetingRoomPage.isLiveSession(broadcast), isTrue);
      expect(MeetingRoomPage.isLiveSession(plain), isFalse);
      await meeting.dispose();
      await broadcast.dispose();
      await plain.dispose();
    },
  );
  testWidgets('Demo displays SDK meeting UI at phone, tablet and desktop sizes', (
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

    for (final width in [
      320.0,
      390.0,
      520.0,
      600.0,
      768.0,
      1024.0,
      1280.0,
      1440.0,
    ]) {
      await tester.binding.setSurfaceSize(Size(width, 840));
      await tester.pumpWidget(
        designCaptureApp(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: designTestTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 320 ? 2 : 1)),
              child: child!,
            ),
            home: DemoComposableMeetingPage(
              room: room,
              initialSettings: const MediaLocalPreviewSettings(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(RealtimeRoomUiScope), findsOneWidget);
      expect(find.byType(RealtimeVideoGrid), findsOneWidget);
      expect(find.byTooltip('Meeting participant'), findsOneWidget);
      expect(find.byType(RealtimeMeetingRail), findsOneWidget);
      expect(find.byType(RealtimeDockMoreButton), findsNothing);
      expect(find.byType(RealtimeDockRaiseHandButton), findsOneWidget);
      expect(find.byType(RealtimeDockHandQueueButton), findsNothing);
      if (width >= 1280) {
        final backgrounds = find.byIcon(Icons.blur_on_outlined);
        expect(
          backgrounds,
          findsOneWidget,
          reason:
              'Desktop meeting exposes one background action in the rail at '
              '$width',
        );
        expect(
          find.descendant(
            of: find.byType(RealtimeMeetingRail),
            matching: backgrounds,
          ),
          findsOneWidget,
        );
      }
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
      if (width <= 520) {
        final header = tester.getRect(find.byType(RealtimeMeetingTopBar));
        expect(
          header.height,
          lessThan(width == 320 ? 150 : 90),
          reason: 'Compact header stays balanced at $width with large text',
        );
        expect(
          tester.getTopLeft(find.byType(RealtimeMeetingTimerBadge)).dx,
          lessThan(width / 2),
        );
      }
      expect(tester.takeException(), isNull);
      if ([390.0, 520.0, 1440.0].contains(width)) {
        await captureDesign(tester, 'meeting-${width.toInt()}');
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'meeting shows a focused speaker and switches it from thumbnails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = _FakeMeetingSession(
        participants: const [
          MediaParticipant(id: 'self', displayName: 'Local', isLocal: true),
          MediaParticipant(id: 'alice', displayName: 'Alice', isSpeaking: true),
          MediaParticipant(id: 'bob', displayName: 'Bob'),
        ],
      );
      final room = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'multi-member',
          participantId: 'self',
          session: session,
        ),
        renderer: const _FakeTrackRenderer(),
        disposeClients: () {},
      );
      addTearDown(room.dispose);
      await tester.pumpWidget(
        designCaptureApp(
          MaterialApp(
            theme: designTestTheme(),
            home: DemoComposableMeetingPage(
              room: room,
              initialSettings: const MediaLocalPreviewSettings(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final stage = find.byType(RealtimeMeetingFilmstripStage);
      expect(stage, findsOneWidget);
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(stage)
            .primaryParticipant
            .id,
        'alice',
      );
      expect(find.byType(RealtimeIdleControls), findsOneWidget);
      await captureDesign(tester, 'meeting-multi-1280');
      await tester.tap(find.text('Bob'));
      await tester.pump();
      expect(
        tester
            .widget<RealtimeMeetingFilmstripStage>(stage)
            .primaryParticipant
            .id,
        'bob',
      );
      // Room controls stay on screen: the dock intentionally does not fade.
      final dockFadeBars = find.descendant(
        of: find.byType(RealtimeIdleControls),
        matching: find.byType(AnimatedOpacity),
      );
      expect(dockFadeBars, findsOneWidget);
      final persistentHeader = tester.getRect(
        find.byType(RealtimeMeetingTopBar),
      );
      expect(persistentHeader.height, inInclusiveRange(56, 90));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 300));
      // Idling must not hide the room actions.
      expect(
        tester
            .widgetList<AnimatedOpacity>(dockFadeBars)
            .every((bar) => bar.opacity == 1),
        isTrue,
      );
      await tester.tapAt(const Offset(600, 400));
      await tester.pump();
      expect(
        tester
            .widgetList<AnimatedOpacity>(dockFadeBars)
            .every((bar) => bar.opacity == 1),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'desktop two-person grid fills stage and header layout switch stays tappable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1120, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final room = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'grid-header-room',
          participantId: 'self',
          session: _FakeMeetingSession(
            participants: const [
              MediaParticipant(id: 'self', displayName: 'Local', isLocal: true),
              MediaParticipant(id: 'remote', displayName: 'Remote'),
            ],
          ),
        ),
        renderer: const _FakeTrackRenderer(),
        disposeClients: () {},
      );
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: designTestTheme(),
          home: DemoComposableMeetingPage(
            room: room,
            initialSettings: const MediaLocalPreviewSettings(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RealtimeMeetingFilmstripStage), findsOneWidget);

      // Layout is a single rail toggle; there is no stage bar above the tiles.
      final gridAction = find.descendant(
        of: find.byType(RealtimeMeetingRail),
        matching: find.byTooltip('Grid view'),
      );
      expect(gridAction, findsOneWidget);
      await tester.tap(gridAction);
      await tester.pump();

      expect(find.byType(RealtimeVideoGrid), findsOneWidget);
      final tiles = find.descendant(
        of: find.byType(RealtimeVideoGrid),
        matching: find.byType(RealtimeVideoTile),
      );
      expect(tiles, findsNWidgets(2));
      final first = tester.getRect(tiles.first);
      final second = tester.getRect(tiles.last);
      expect(first.height, greaterThan(500));
      expect(first.height, closeTo(second.height, 1));
      expect(first.left, lessThan(second.left));
      expect(first.bottom, lessThan(800)); // Above the floating dock.

      final focusAction = find.descendant(
        of: find.byType(RealtimeMeetingRail),
        matching: find.byTooltip('Speaker view'),
      );
      expect(focusAction, findsOneWidget);
      await tester.tap(focusAction);
      await tester.pump();
      expect(find.byType(RealtimeMeetingFilmstripStage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide meeting header cannot cover the right sidebar or its tabs',
    (tester) async {
      for (final width in [1024.0, 1280.0]) {
        await tester.binding.setSurfaceSize(Size(width, 820));
        final room = RealtimeRoom(
          media: MediaRoomSession.direct(
            roomCode: 'stage-sidebar-room',
            participantId: 'self',
            session: _FakeMeetingSession(
              participants: const [
                MediaParticipant(
                  id: 'self',
                  displayName: 'Local',
                  isLocal: true,
                ),
                MediaParticipant(id: 'remote', displayName: 'Remote'),
              ],
            ),
          ),
          renderer: const _FakeTrackRenderer(),
          disposeClients: () {},
        );
        addTearDown(room.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: designTestTheme(),
            home: DemoComposableMeetingPage(
              room: room,
              initialSettings: const MediaLocalPreviewSettings(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));

        // Desktop panels open from the vertical tool rail; the dock keeps
        // media, collaboration and the exit action.
        final participantAction = find.descendant(
          of: find.byType(RealtimeMeetingRail),
          matching: find.byTooltip('Participants'),
        );
        expect(participantAction, findsOneWidget);
        await tester.tap(participantAction);
        await tester.pump(const Duration(milliseconds: 300));

        final sidebar = find.byType(RealtimeMeetingSidePanel);
        final topBar = find.byType(RealtimeMeetingTopBar);
        expect(sidebar, findsOneWidget);
        final sidebarRect = tester.getRect(sidebar);
        final topBarRect = tester.getRect(topBar);
        // The header is persistent chrome above the whole workspace: the
        // stage and the trailing panel both start below it, so nothing is
        // painted over the panel's tabs.
        expect(
          topBarRect.bottom,
          lessThanOrEqualTo(sidebarRect.top + 1),
          reason: 'Header overlays the right sidebar at width $width',
        );
        expect(topBarRect.height, lessThan(75));
        final close = find.descendant(
          of: sidebar,
          matching: find.byTooltip('Close Sidebar'),
        );
        expect(close, findsOneWidget);
        // Below the 56 pt header plus the sidebar's own tab row.
        expect(tester.getRect(close).top, lessThan(130));
        await tester.tap(close);
        await tester.pump();
        expect(find.byType(RealtimeMeetingSidePanel), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}

class _FakeTrackRenderer extends MediaTrackRenderer {
  const _FakeTrackRenderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.expand();
}

class _FakeMeetingSession extends Fake implements InteractiveMediaSession {
  _FakeMeetingSession({
    List<MediaParticipant> participants = const [
      MediaParticipant(id: 'self', displayName: 'Local', isLocal: true),
    ],
  }) : _snapshot = MediaSnapshot(
         state: MediaSessionState.connected,
         capabilities: const MediaCapabilities.meeting(),
         participants: participants,
       );
  MediaSnapshot _snapshot;
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
  Future<void> setMuted(bool muted) async {
    _snapshot = _snapshot.copyWith(localMuted: muted);
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    _snapshot = _snapshot.copyWith(localVideoEnabled: enabled);
  }

  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() async {}
}
