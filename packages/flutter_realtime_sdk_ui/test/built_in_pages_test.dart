import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

void main() {
  testWidgets('viewer can retry room entry without opening local capture', (
    tester,
  ) async {
    var entries = 0;
    var previews = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimePreJoinPage(
          permissionRequester: const _Permissions(),
          roomLabel: 'room',
          displayName: 'Viewer',
          runCheck: () async => const MediaPreJoinResult(
            role: MediaRole.viewer,
            providerId: 'custom',
            checks: [
              MediaPreJoinCheck(
                type: MediaPreJoinCheckType.backend,
                status: MediaPreJoinStatus.passed,
                severity: MediaPreJoinSeverity.blocking,
                message: 'Ready',
              ),
            ],
          ),
          openPreview: (_, _) async {
            previews++;
            return null;
          },
          onEnter: (_, settings) async {
            expect(settings.microphoneEnabled, isFalse);
            expect(settings.cameraEnabled, isFalse);
            entries++;
            if (entries == 1) {
              throw const RealtimeException(
                code: RealtimeErrorCode.network,
                message: 'room.connect',
              );
            }
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(RealtimePreJoinJoinButton));
    await tester.pumpAndSettle();
    expect(entries, 1);
    final controller = RealtimePreJoinScope.of(
      tester.element(find.byType(RealtimePreJoinJoinButton)),
    );
    expect(controller.joinError?.code, RealtimeErrorCode.network);
    expect(find.textContaining(controller.joinError!.message), findsOneWidget);
    await tester.tap(find.byType(RealtimePreJoinJoinButton));
    await tester.pumpAndSettle();
    expect(entries, 2);
    expect(previews, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recording layout choices follow the backend for an unknown provider',
    (tester) async {
      final cloud = _CloudRecorder();
      final room = _room(cloud);
      addTearDown(room.dispose);
      RecordingLayout? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await showRealtimeRecordingLayoutPicker(
                    context,
                    room,
                  );
                },
                child: const Text('Choose layout'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose layout'));
      await tester.pumpAndSettle();
      expect(find.text('Grid recording'), findsOneWidget);
      expect(
        find.text('Active speaker (switches automatically)'),
        findsNothing,
      );
      await tester.tap(find.text('Grid recording'));
      await tester.pumpAndSettle();
      expect(chosen, RecordingLayout.grid);
      expect(cloud.queries, 1);
    },
  );

  testWidgets(
    'recording results expose download only after completion and stop polling on unmount',
    (tester) async {
      final cloud = _CloudRecorder();
      final room = _room(cloud);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(home: RealtimeRecordingResultDialog(room: room)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsNothing);
      cloud.taskState = RecordingTaskState.completed;
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsOneWidget);
      final queries = cloud.queries;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 8));
      expect(cloud.queries, queries);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an injected recorder enables host controls without a known provider id',
    (tester) async {
      final room = _room(_CloudRecorder());
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: RealtimeRecordingButton(room: room)),
          ),
        ),
      );
      final start = tester.widget<RealtimeDockItem>(
        find.widgetWithText(RealtimeDockItem, 'Cloud recording'),
      );
      expect(start.onPressed, isNotNull);
    },
  );
}

RealtimeRoom _room(_CloudRecorder cloud) => RealtimeRoom(
  media: MediaRoomSession.direct(
    roomCode: 'recording-room',
    participantId: 'host',
    session: _MediaSession(),
  ),
  renderer: const _Renderer(),
  cloudRecordingSession: cloud,
  disposeClients: () {},
);

class _MediaSession extends Fake implements MediaSession {
  @override
  String get providerId => 'custom-provider';
  @override
  MediaRole get role => MediaRole.host;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  MediaSnapshot get snapshot => MediaSnapshot(
    state: MediaSessionState.connected,
    capabilities: capabilities,
  );
  @override
  Stream<MediaEvent> get events => const Stream.empty();
  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() async {}
}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.shrink();
}

class _CloudRecorder extends Fake implements MediaCloudRecordingSession {
  var queries = 0;
  var taskState = RecordingTaskState.processing;
  @override
  Future<RecordingResult> queryCloudRecording() async {
    queries++;
    return RecordingResult(
      mode: RecordingMode.cloud,
      taskState: taskState,
      metadata: {
        'supportedLayouts': ['grid'],
        'canDownload': taskState == RecordingTaskState.completed,
      },
    );
  }

  @override
  void dispose() {}
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
