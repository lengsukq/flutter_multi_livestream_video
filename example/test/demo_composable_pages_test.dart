import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_example/demo_composable_live_page.dart';
import 'package:flutter_realtime_media_example/demo_composable_pre_join_page.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Live viewer Demo owns responsive stage and actions', (
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
    for (final width in [390.0, 768.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 850));
      await tester.pumpWidget(
        MaterialApp(
          home: DemoComposableLivePage(
            room: room,
            initialSettings: const MediaLocalPreviewSettings(),
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
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Pre-Join Demo composes preview, checks and join at any width', (
    tester,
  ) async {
    for (final width in [390.0, 768.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 850));
      await tester.pumpWidget(
        MaterialApp(
          home: DemoComposablePreJoinPage(
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
      );
      await tester.pumpAndSettle();
      expect(
        find.text('As a viewer, no camera or microphone is needed'),
        findsOneWidget,
      );
      expect(find.byType(RealtimePreJoinPreview), findsNothing);
      expect(find.byType(RealtimePreJoinJoinButton), findsOneWidget);
      expect(find.text('All systems ready'), findsOneWidget);
      expect(find.byType(RealtimePreJoinReadinessCard), findsOneWidget);
      // The page survives surface-size changes; its expansion state may
      // persist between viewport iterations.
      if (find.byType(RealtimePreJoinCheckList).evaluate().isEmpty) {
        await tester.ensureVisible(find.text('All systems ready'));
        await tester.tap(find.text('All systems ready'));
        await tester.pumpAndSettle();
      }
      expect(
        find.byType(RealtimePreJoinCheckList, skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _LiveMediaSession extends Fake implements MediaSession {
  final _snapshot = MediaSnapshot(
    state: MediaSessionState.connected,
    role: MediaRole.viewer,
    capabilities: const MediaCapabilities.broadcastViewer(),
    participants: const [
      MediaParticipant(id: 'viewer', displayName: 'Viewer', isLocal: true),
      MediaParticipant(id: 'host', displayName: 'Host', isVideoEnabled: true),
    ],
  );
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.viewer;
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
