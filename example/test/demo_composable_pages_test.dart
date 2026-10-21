import 'dart:async';

import 'support/design_capture.dart';
import 'package:flutter/material.dart';
import 'package:multi_video/demo_composable_live_page.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDesignCapture);
  testWidgets('Live viewer Demo displays SDK responsive stage and actions', (
    tester,
  ) async {
    final media = _LiveMediaSession();
    final room = RealtimeRoom(
      media: MediaRoomSession.direct(
        roomCode: 'broadcast-123',
        participantId: 'viewer',
        session: media,
      ),
      renderer: const _Renderer(),
      disposeClients: () {},
    );
    addTearDown(room.dispose);
    for (final width in [320.0, 390.0, 600.0, 768.0, 1024.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 850));
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
            home: DemoComposableLivePage(
              room: room,
              initialSettings: const MediaLocalPreviewSettings(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(RealtimeRoomUiScope), findsOneWidget);
      expect(find.byType(RealtimeLiveVideoStage), findsOneWidget);
      expect(find.byType(RealtimeMicrophoneButton), findsNothing);
      final rect = tester.getRect(find.byType(RealtimeLeaveButton));
      expect(width - rect.right, lessThanOrEqualTo(32));
      expect(tester.takeException(), isNull);
      if ([390.0, 1440.0].contains(width)) {
        await captureDesign(tester, 'live-${width.toInt()}');
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('non-host live participant never receives broadcaster controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final room = RealtimeRoom(
      media: MediaRoomSession.direct(
        roomCode: 'role-test',
        participantId: 'guest',
        session: _LiveMediaSession(role: MediaRole.participant),
      ),
      renderer: const _Renderer(),
      disposeClients: () {},
    );
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DemoComposableLivePage(
          room: room,
          initialSettings: const MediaLocalPreviewSettings(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RealtimeLiveMediaControls), findsNothing);
    expect(find.byTooltip('Host tools'), findsNothing);
    expect(find.byTooltip('Turn on microphone'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Live host can operate media at every width without crowded header actions',
    (tester) async {
      final media = _LiveMediaSession(role: MediaRole.host);
      final room = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'broadcast-123',
          participantId: 'viewer',
          session: media,
        ),
        renderer: const _Renderer(),
        disposeClients: () {},
      );
      addTearDown(room.dispose);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [
        const Size(320, 640),
        const Size(390, 844),
        const Size(550, 940),
        const Size(768, 960),
        const Size(1024, 800),
        const Size(1440, 900),
        const Size(768, 390),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          designCaptureApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: designTestTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 320 ? 2 : 1),
                ),
                child: child!,
              ),
              home: DemoComposableLivePage(
                room: room,
                initialSettings: const MediaLocalPreviewSettings(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(media.microphoneCalls, 0);
        expect(media.cameraCalls, 0);
        expect(find.byTooltip('Turn on microphone'), findsOneWidget);
        expect(find.byTooltip('Turn on camera'), findsOneWidget);
        expect(
          tester.getSize(find.byTooltip('Turn on microphone')).shortestSide,
          greaterThanOrEqualTo(48),
        );
        if (size.width < 1000) {
          final exit = tester.getRect(find.byType(RealtimeLeaveButton));
          final more = tester.getRect(find.byTooltip('Display options'));
          expect((more.center.dy - exit.center.dy).abs(), lessThan(1));
          expect(find.byIcon(Icons.fit_screen_rounded), findsNothing);
        } else {
          // Background effects live only inside Host Tools, so the header
          // carries a single settings surface.
          expect(find.byTooltip('Virtual background'), findsNothing);
          expect(find.byTooltip('Host Tools'), findsOneWidget);
        }
        expect(tester.takeException(), isNull, reason: 'Host $size');
        if ([390.0, 550.0, 1440.0].contains(size.width)) {
          await captureDesign(tester, 'live-host-${size.width.toInt()}');
        }
      }
      await tester.binding.setSurfaceSize(const Size(390, 844));
      // FlutterView padding is physical; model a 44/34 logical-pixel safe area.
      tester.view.viewPadding = FakeViewPadding(
        top: 44 * tester.view.devicePixelRatio,
        bottom: 34 * tester.view.devicePixelRatio,
      );
      // FakeFlutterView exposes padding separately from viewPadding.
      tester.view.padding = tester.view.viewPadding;
      await tester.pump();
      final cameraRect = tester.getRect(find.byTooltip('Turn on camera'));
      expect(cameraRect.bottom, lessThan(844 - 34));
      await tester.tap(find.byTooltip('Turn on microphone'));
      await tester.pumpAndSettle();
      expect(media.microphoneCalls, 1);
      expect(find.byTooltip('Turn off microphone'), findsOneWidget);
      await tester.tap(find.byTooltip('Turn on camera'));
      await tester.pumpAndSettle();
      expect(media.cameraCalls, 1);
      expect(find.byTooltip('Turn off camera'), findsOneWidget);
      await tester.tap(find.byTooltip('Display options'));
      await tester.pumpAndSettle();
      expect(find.text('Show full video'), findsOneWidget);
      expect(find.text('Virtual background'), findsNothing);
      expect(find.text('Host tools'), findsOneWidget);
      await tester.tap(find.text('Show full video'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RealtimeLiveVideoStage>(find.byType(RealtimeLiveVideoStage))
            .fit,
        BoxFit.contain,
      );
      await tester.tap(find.byTooltip('Display options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide controls'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Display options'), findsNothing);
      await tester.tap(find.text('Exit clean screen'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Display options'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tiny live windows fit controls and received hearts disappear', (
    tester,
  ) async {
    final repository = _LikesRepository();
    final room = (await tester.runAsync(() async {
      final room = RealtimeRoom(
        media: MediaRoomSession.direct(
          roomCode: 'live',
          participantId: 'viewer',
          session: _LiveMediaSession(role: MediaRole.host),
        ),
        renderer: const _Renderer(),
        disposeClients: () {},
        featurePlugins: [
          LivePreset(
            enableForDirectRooms: true,
            repositoryFactory: (_) => repository,
            pollInterval: const Duration(hours: 1),
          ),
        ],
      );
      await room.initialize();
      return room;
    }))!;
    addTearDown(room.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [176.0, 200.0, 240.0, 280.0, 320.0]) {
      for (final scale in [1.0, 2.0]) {
        final height = width == 176 ? 250.0 : 520.0;
        await tester.binding.setSurfaceSize(Size(width, height));
        await tester.pumpWidget(
          designCaptureApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: designTestTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: DemoComposableLivePage(
                room: room,
                initialSettings: const MediaLocalPreviewSettings(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        for (final finder in [
          find.byType(RealtimeLeaveButton),
          find.byTooltip('Turn on microphone'),
          find.byTooltip('Turn on camera'),
          find.byTooltip('Display options'),
        ]) {
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(height));
        }
        expect(
          tester.getRect(find.byTooltip('Turn on microphone')).top,
          greaterThanOrEqualTo(
            tester.getRect(find.byType(RealtimeLeaveButton)).bottom,
          ),
        );
        expect(tester.takeException(), isNull, reason: '$width at $scale');
        if (width == 176 && scale == 1) {
          await captureDesign(tester, 'live-host-176');
        }
      }
    }
    final heart = find.descendant(
      of: find.byType(RealtimeLiveHeartsOverlay),
      matching: find.byIcon(Icons.favorite_rounded),
    );
    expect(heart, findsNothing);
    await room.liveInteractions!.sendLike();
    await tester.pump();
    expect(heart, findsOneWidget);
    expect(tester.widget<Icon>(heart).color, RealtimeStyle.light.live);
    await tester.pump(const Duration(milliseconds: 400));
    await room.liveInteractions!.sendLike();
    await tester.pump();
    expect(heart, findsNWidgets(2));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(heart, findsNothing);
    expect(find.byType(RealtimeLiveLikeButton), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(room.dispose);
  });

  testWidgets(
    'Pre-Join Demo displays SDK preview, checks and join at any width',
    (tester) async {
      for (final width in [
        320.0,
        390.0,
        600.0,
        768.0,
        1024.0,
        1280.0,
        1440.0,
      ]) {
        await tester.binding.setSurfaceSize(Size(width, 850));
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
              home: RealtimePreJoinPage(
                roomLabel: 'room-123',
                displayName: 'Example',
                runCheck: () async => const MediaPreJoinResult(
                  role: MediaRole.viewer,
                  providerId: 'fake',
                  checks: [
                    MediaPreJoinCheck(
                      type: MediaPreJoinCheckType.backend,
                      status: MediaPreJoinStatus.passed,
                      severity: MediaPreJoinSeverity.blocking,
                      message: 'Ready',
                    ),
                  ],
                ),
                openPreview: (_, _) async => null,
                onEnter: (_, _) async {},
                permissionRequester: const _Permissions(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('As a viewer, no camera or microphone is needed'),
          findsOneWidget,
        );
        expect(find.byType(RealtimePreJoinPreview), findsNothing);
        expect(find.byType(RealtimePreJoinJoinButton), findsOneWidget);
        expect(
          find.byType(RealtimePreJoinReadinessCard, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('All systems ready', skipOffstage: false),
          findsOneWidget,
        );
        // The page survives surface-size changes; its expansion state may
        // persist between viewport iterations.
        if (find.byType(RealtimePreJoinCheckList).evaluate().isEmpty) {
          // At 200% text the sticky join action occupies more vertical space.
          // Place the readiness trigger well inside its own scroll viewport.
          await Scrollable.ensureVisible(
            tester.element(find.text('All systems ready', skipOffstage: false)),
            alignment: 0.2,
            alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('All systems ready', skipOffstage: false));
          await tester.pumpAndSettle();
        }
        expect(
          find.byType(RealtimePreJoinCheckList, skipOffstage: false),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if ([390.0, 1440.0].contains(width)) {
          await captureDesign(tester, 'prejoin-${width.toInt()}');
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );
}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _LiveMediaSession extends Fake implements InteractiveMediaSession {
  _LiveMediaSession({this.role = MediaRole.viewer});
  final _updates = StreamController<MediaSnapshot>.broadcast();
  int microphoneCalls = 0;
  int cameraCalls = 0;
  late var _snapshot = MediaSnapshot(
    state: MediaSessionState.connected,
    role: role,
    capabilities: role == MediaRole.viewer
        ? const MediaCapabilities.broadcastViewer()
        : const MediaCapabilities.broadcastHost(),
    participants: const [
      MediaParticipant(id: 'viewer', displayName: 'Viewer', isLocal: true),
      MediaParticipant(id: 'host', displayName: 'Host', isVideoEnabled: true),
    ],
  );
  @override
  String get providerId => 'fake';
  @override
  final MediaRole role;
  @override
  MediaCapabilities get capabilities => _snapshot.capabilities;
  @override
  MediaSessionState get state => _snapshot.state;
  @override
  MediaSnapshot get snapshot => _snapshot;
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaSnapshot> get snapshots => _updates.stream;
  @override
  Stream<MediaEvent> get events => const Stream.empty();
  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() => _updates.close();
  @override
  Future<void> setMuted(bool muted) async {
    if (_snapshot.localMuted != muted) await toggleMute();
  }

  @override
  Future<void> toggleMute() async {
    microphoneCalls++;
    _snapshot = _snapshot.copyWith(localMuted: !_snapshot.localMuted);
    _updates.add(_snapshot);
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    cameraCalls++;
    _snapshot = _snapshot.copyWith(localVideoEnabled: enabled);
    _updates.add(_snapshot);
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {}
}

class _LikesRepository extends Fake implements LiveInteractionRepository {
  final List<LiveLikeEvent> _events = [];
  @override
  Future<LiveInteractionState> snapshot() async => LiveInteractionState(
    roomCode: 'live',
    revision: _events.length,
    selfUserId: 'self',
    recipientId: 'host',
    canSendGift: true,
    totalLikes: _events.length,
    likeEvents: _events,
  );
  @override
  Future<LiveInteractionState> sendLike({required String eventId}) {
    _events.add(
      LiveLikeEvent(
        id: eventId,
        sequence: _events.length + 1,
        userId: 'self',
        quantity: 1,
        timestamp: DateTime(2026),
      ),
    );
    return snapshot();
  }

  @override
  void close() {}
}

class _Permissions implements MediaPermissionRequester {
  const _Permissions();
  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
  @override
  bool get canOpenAppSettings => false;
  @override
  Future<bool> openAppSettings() async => false;
}
