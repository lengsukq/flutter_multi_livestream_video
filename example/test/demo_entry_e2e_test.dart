import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_example/demo_join_screen.dart';
import 'package:flutter_realtime_media_example/demo_composable_pre_join_page.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRealtime extends Fake implements Realtime {
  _FakeRealtime({this.rooms = const []});

  final List<MediaRoomSummary> rooms;
  final List<RealtimeRequest> opened = [];
  Future<RealtimeConnection> Function(RealtimeRequest request)? onOpen;

  @override
  Future<List<MediaRoomSummary>> listRooms() async => rooms;

  @override
  Future<MediaDoctorReport> diagnoseBackend() async => const MediaDoctorReport(
    [
      MediaDoctorCheck(
        id: 'backend',
        status: MediaDoctorStatus.pass,
        message: 'Ready',
      ),
    ],
    backendReachable: true,
    activeProvider: 'livekit',
  );

  @override
  Future<MediaPreJoinResult> preJoin({
    MediaRole role = MediaRole.participant,
    String? providerId,
    String? roomCode,
    MediaPreJoinRequirements? requirements,
  }) async => MediaPreJoinResult(
    role: role,
    providerId: providerId ?? 'livekit',
    checks: const [
      MediaPreJoinCheck(
        type: MediaPreJoinCheckType.backend,
        status: MediaPreJoinStatus.passed,
        severity: MediaPreJoinSeverity.blocking,
        message: 'Backend ready',
      ),
    ],
  );

  @override
  Future<MediaLocalPreviewSession?> createLocalPreview({
    required String providerId,
    required MediaRole role,
  }) async => null;

  @override
  Future<RealtimeConnection> open(RealtimeRequest request) {
    opened.add(request);
    return onOpen!(request);
  }
}

class _FakeConnection extends Fake implements RealtimeConnection {
  int disposeCount = 0;

  @override
  RealtimeRoom? get mediaRoom => null;

  @override
  Future<void> dispose() async => disposeCount++;
}

class _FakePermissionRequester implements MediaPermissionRequester {
  const _FakePermissionRequester();

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

Future<void> _pumpDemo(
  WidgetTester tester,
  _FakeRealtime fake, {
  required ValueChanged<MediaRoomMode?> onRoom,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 850);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: RealtimeUiTheme.light(),
      supportedLocales: RealtimeStrings.supportedLocales,
      localizationsDelegates: RealtimeStrings.localizationsDelegates,
      home: JoinScreen(
        onLocaleChanged: (_) {},
        initialBackendUrl: 'http://fake-backend:3000',
        realtimeFactory: (_) => fake,
        backgroundPresets: () async => const [],
        permissionRequester: const _FakePermissionRequester(),
        roomPageFactory: (_, settings, mode) => Scaffold(
          appBar: AppBar(title: const Text('Connected fake room')),
          body: Column(
            children: [
              Text('microphone: ${settings.microphoneEnabled}'),
              FilledButton(
                onPressed: () {
                  onRoom(mode);
                  Navigator.of(
                    tester.element(find.text('Connected fake room')),
                  ).pop();
                },
                child: const Text('Leave fake room'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _confirmPreJoin(WidgetTester tester) async {
  // A provider preview may animate continuously; pump finite frames instead
  // of waiting for every animation to settle.
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(DemoComposablePreJoinPage).evaluate().isNotEmpty) break;
  }
  expect(find.byType(DemoComposablePreJoinPage), findsOneWidget);
  final enter = find.text('Join meeting').evaluate().isNotEmpty
      ? find.text('Join meeting').last
      : find.text('Enter live room').last;
  expect(enter, findsOneWidget);
  await tester.tap(enter);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'create meeting stays on Pre-Join while connecting, then enters room once',
    (tester) async {
      final fake = _FakeRealtime();
      final opened = Completer<RealtimeConnection>();
      final connection = _FakeConnection();
      fake.onOpen = (_) => opened.future;
      final roomModes = <MediaRoomMode?>[];
      await _pumpDemo(tester, fake, onRoom: roomModes.add);
      await tester.tap(find.text('Create meeting').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create meeting').last);
      await tester.pump();
      await tester.tap(find.text('Create meeting').last);
      await _confirmPreJoin(tester);

      // The in-place loading overlay and its disabled join action may both
      // render the same status label. What matters is that navigation has not
      // occurred while the connection is pending.
      expect(find.text('Entering room…'), findsWidgets);
      final blockingOverlays = find.ancestor(
        of: find.text('Entering room…').last,
        matching: find.byType(AbsorbPointer),
      );
      expect(
        blockingOverlays.evaluate().any(
          (element) => (element.widget as AbsorbPointer).absorbing,
        ),
        isTrue,
      );
      expect(find.text('Connected fake room'), findsNothing);
      expect(fake.opened, hasLength(1));
      expect(fake.opened.single.experience, RealtimeExperience.meeting);
      expect(fake.opened.single.action, RealtimeAction.create);

      opened.complete(connection);
      await tester.pumpAndSettle();
      expect(find.text('Connected fake room'), findsOneWidget);
      expect(find.byType(DemoComposablePreJoinPage), findsNothing);
      await tester.tap(find.text('Leave fake room'));
      await tester.pumpAndSettle();
      expect(roomModes, [MediaRoomMode.meeting]);
      expect(connection.disposeCount, 1);
      expect(find.text('Join room'), findsWidgets);
    },
  );

  testWidgets(
    'failed join remains on Pre-Join and retries without returning home',
    (tester) async {
      final fake = _FakeRealtime();
      final connection = _FakeConnection();
      var attempts = 0;
      fake.onOpen = (_) async {
        if (++attempts == 1) throw StateError('simulated connection failure');
        return connection;
      };
      await _pumpDemo(tester, fake, onRoom: (_) {});
      await tester.enterText(find.byType(TextField).first, '3456');
      await tester.ensureVisible(find.text('Join room').last);
      await tester.pump();
      await tester.tap(find.text('Join room').last);
      await _confirmPreJoin(tester);
      await tester.pumpAndSettle();
      expect(find.byType(DemoComposablePreJoinPage), findsOneWidget);
      // Raw transport errors are normalized while the retry keeps its room code.
      expect(find.textContaining('simulated connection failure'), findsNothing);
      expect(find.textContaining('The SDK operation failed'), findsOneWidget);
      await tester.tap(find.text('Join meeting').last);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Connected fake room'), findsOneWidget);
      expect(
        fake.opened.every((request) => request.roomCode == '3456'),
        isTrue,
      );
      await tester.tap(find.text('Leave fake room'));
      await tester.pumpAndSettle();
      expect(connection.disposeCount, 1);
    },
  );

  testWidgets(
    'discovered live room joins as viewer using the original room provider',
    (tester) async {
      final fake = _FakeRealtime(
        rooms: const [
          MediaRoomSummary(
            roomCode: '5678',
            providerId: 'aws',
            engineId: 'ivs',
            roomMode: MediaRoomMode.broadcast,
            attendeeCount: 2,
          ),
        ],
      );
      final connection = _FakeConnection();
      fake.onOpen = (_) async => connection;
      final modes = <MediaRoomMode?>[];
      await _pumpDemo(tester, fake, onRoom: modes.add);
      await tester.ensureVisible(find.text('5678').first);
      await tester.pump();
      await tester.tap(find.text('5678').first);
      await _confirmPreJoin(tester);
      await tester.pumpAndSettle();
      expect(fake.opened.single.action, RealtimeAction.join);
      expect(fake.opened.single.experience, RealtimeExperience.live);
      expect(fake.opened.single.roomCode, '5678');
      expect(find.text('Connected fake room'), findsOneWidget);
      await tester.tap(find.text('Leave fake room'));
      await tester.pumpAndSettle();
      expect(modes, [MediaRoomMode.broadcast]);
      expect(connection.disposeCount, 1);
    },
  );
}
