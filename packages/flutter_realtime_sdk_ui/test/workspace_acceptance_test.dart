import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/design_capture.dart';
import 'support/meeting_sharing_fixture.dart';

// These fixtures exercise SDK UI with in-memory state, never real media/cloud.
void main() {
  setUpAll(initializeDesignCapture);

  testWidgets(
    'teacher workspace keeps shared content, camera and actions reachable',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final mode in [
        SharedContentMode.whiteboard,
        SharedContentMode.screen,
      ]) {
        final cloud = _PreviewRecorder();
        final fixture = await MeetingSharingFixture.create(
          mode: mode,
          localShare: true,
          withTrack: mode == SharedContentMode.screen,
          renderer: const _PreviewRenderer(),
          cloudRecording: cloud,
          role: MediaRole.host,
          chat: _PreviewChat(),
        );
        final repository = fixture.repository!;
        repository.annotationActive = true;
        final board = repository.whiteboard;
        repository.whiteboard = WhiteboardState(
          revision: board.revision,
          canEdit: board.canEdit,
          pages: board.pages,
          activePageId: board.activePageId,
          canvas: AnnotationCanvas(
            canvasId: board.canvas.canvasId,
            sourceKey: board.canvas.sourceKey,
            participantId: board.canvas.participantId,
            shapes: [
              AnnotationShape(
                id: 'title',
                tool: AnnotationTool.text,
                points: const [AnnotationPoint(.08, .12)],
                text: 'Finding the roots',
                color: 0xff1f2a3c,
              ),
              AnnotationShape(
                id: 'equation',
                tool: AnnotationTool.text,
                points: const [AnnotationPoint(.12, .32)],
                text: 'x² − 5x + 6 = 0',
                color: 0xff1f2a3c,
              ),
              AnnotationShape(
                id: 'factor',
                tool: AnnotationTool.text,
                points: const [AnnotationPoint(.12, .52)],
                text: '(x − 2)(x − 3) = 0',
                color: 0xff2e6fd8,
              ),
              AnnotationShape(
                id: 'answer',
                tool: AnnotationTool.text,
                points: const [AnnotationPoint(.12, .74)],
                text: 'x = 2   or   x = 3',
                color: 0xff0b7f72,
              ),
            ],
          ),
        );
        await fixture.room.classroom!.refresh();
        for (final size in const [
          Size(320, 640),
          Size(390, 844),
          Size(600, 850),
          Size(768, 960),
          Size(1024, 850),
          Size(1280, 900),
          Size(1440, 900),
          Size(740, 390),
        ]) {
          for (final scale in [1.0, 2.0]) {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
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
                  home: RealtimeMeetingPage(
                    room: fixture.room,
                    sessionInfo: const RealtimeMeetingSessionInfo(
                      title: 'Quadratics: finding the roots',
                      subtitle: 'Sample classroom · Algebra II',
                    ),
                    pinnedMessage:
                        'Sample lesson: factor the equation, then share your roots.',
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.byType(RealtimeMeetingDock), findsOneWidget);
            final dock = tester.getRect(find.byType(RealtimeMeetingDock));
            expect(dock.bottom, lessThanOrEqualTo(size.height));
            if (size.width >= 1000 && scale == 1) {
              expect(find.byType(RealtimeClassroomSidePanel), findsOneWidget);
              expect(find.byType(RealtimeSelfView), findsOneWidget);
              expect(
                tester.getSize(find.byType(RealtimeMeetingSidePanel)).width,
                340,
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '$mode $size at $scale',
            );
            if (scale == 1 && [390.0, 768.0, 1440.0].contains(size.width)) {
              await captureDesign(
                tester,
                'classroom-${mode.name}-${size.width.toInt()}',
              );
            }
            if (mode == SharedContentMode.screen &&
                size.width == 1440 &&
                scale == 1) {
              await fixture.room.startRecording();
              await tester.pump();
              final tab = find.descendant(
                of: find.byType(RealtimeClassroomSidePanel),
                matching: find.text('Recording'),
              );
              // The teacher panel now also lists the hand queue, so the tab
              // row scrolls at 340 pt.
              final nextTabs = find.descendant(
                of: find.byType(RealtimeClassroomSidePanel),
                matching: find.byTooltip('Next sidebar tabs'),
              );
              if (nextTabs.evaluate().isNotEmpty) {
                await tester.tap(nextTabs);
                await tester.pumpAndSettle();
              }
              await tester.ensureVisible(tab);
              await tester.pumpAndSettle();
              await tester.tap(tab);
              await tester.pumpAndSettle();
              expect(find.byType(RealtimeRecordingPanel), findsOneWidget);
              expect(find.text('Recording to cloud'), findsOneWidget);
              expect(find.text('Pause'), findsNothing);
              await captureDesign(tester, 'classroom-recording-1440');
              await fixture.room.stopRecording();
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        }
        await tester.runAsync(fixture.room.dispose);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  testWidgets(
    'green room uses host data and keeps a single mobile join action',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in const [
        Size(320, 640),
        Size(390, 844),
        Size(768, 960),
        Size(1440, 1000),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        var joins = 0;
        await tester.pumpWidget(
          designCaptureApp(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: designTestTheme(),
              home: RealtimePreJoinPage(
                roomLabel: 'sample-class',
                displayName: 'Ms. Rivera',
                permissionRequester: const _Permissions(),
                sessionInfo: RealtimePreJoinSessionInfo(
                  title: 'Quadratics: finding the roots',
                  subject: 'Algebra II',
                  scheduleLabel: 'Sample classroom',
                  timeRangeLabel: '4:00 – 5:00 PM',
                  startsAt: DateTime.now().add(const Duration(minutes: 4)),
                  enrolledCount: 6,
                ),
                waitingGuests: const [
                  RealtimePreJoinWaitingGuest(id: 'a', name: 'Ava K.'),
                ],
                agenda: const [
                  RealtimePreJoinAgendaItem(
                    title: 'Warm-up: factor pairs',
                    durationLabel: '5 min',
                  ),
                  RealtimePreJoinAgendaItem(
                    title: 'Factoring the equation',
                    durationLabel: '20 min',
                  ),
                ],
                materials: const [
                  RealtimePreJoinMaterial(
                    id: 'slides',
                    title: 'Lesson slides.pdf',
                  ),
                ],
                runCheck: () async => const MediaPreJoinResult(
                  role: MediaRole.participant,
                  providerId: 'preview',
                  checks: [
                    MediaPreJoinCheck(
                      type: MediaPreJoinCheckType.backend,
                      status: MediaPreJoinStatus.passed,
                      severity: MediaPreJoinSeverity.blocking,
                      message: 'Ready',
                    ),
                  ],
                ),
                openPreview: (_, _) async => _PreviewDevices(),
                onEnter: (_, settings) async {
                  expect(settings.microphoneEnabled, isFalse);
                  expect(settings.cameraEnabled, isFalse);
                  joins++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RealtimePreJoinJoinButton), findsOneWidget);
        expect(find.text('Lesson plan', skipOffstage: false), findsOneWidget);
        expect(find.byType(RealtimePreJoinReadinessCard), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Devices are collapsed by default; the gear on the preview reveals
        // them, which keeps the green room balanced next to the join column.
        expect(
          find.text('System default', skipOffstage: false),
          findsNothing,
        );
        await captureDesign(tester, 'green-room-${size.width.toInt()}');
        await tester.tap(find.byTooltip('Device settings'));
        await tester.pumpAndSettle();
        expect(
          find.text('System default', skipOffstage: false),
          findsNWidgets(3),
        );
        if (size.width == 1440) {
          await captureDesign(tester, 'green-room-settings-1440');
        }
        await tester.ensureVisible(find.byType(RealtimePreJoinJoinButton));
        await tester.tap(find.byType(RealtimePreJoinJoinButton));
        await tester.pumpAndSettle();
        expect(joins, 1);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}

class _Permissions implements MediaPermissionRequester {
  const _Permissions();
  @override
  bool get canOpenAppSettings => false;
  @override
  Future<bool> openAppSettings() async => false;
  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      MediaPermissionState.granted;
}

class _PreviewRecorder implements MediaCloudRecordingSession {
  @override
  Future<RecordingResult> startCloudRecording(RecordingOptions options) async =>
      RecordingResult(
        mode: RecordingMode.cloud,
        taskState: RecordingTaskState.recording,
      );
  @override
  Future<RecordingResult> stopCloudRecording() async => RecordingResult(
    mode: RecordingMode.cloud,
    taskState: RecordingTaskState.processing,
  );
  @override
  Future<RecordingResult> queryCloudRecording() async => RecordingResult(
    mode: RecordingMode.cloud,
    taskState: RecordingTaskState.processing,
  );
  @override
  Future<Uri> cloudRecordingDownloadUrl() async =>
      Uri.parse('https://example.invalid/sample');
  @override
  void dispose() {}
}

class _PreviewChat extends Fake implements ChatSession {
  @override
  String get providerId => 'preview';
  @override
  ChatRole get role => ChatRole.host;
  @override
  ChatCapabilities get capabilities =>
      const ChatCapabilities(canSendMessage: true);
  @override
  ChatConnectionState get state => ChatConnectionState.connected;
  @override
  List<ChatMessage> get messages => [
    ChatMessage(
      id: '1',
      userId: 'guest',
      displayName: 'Ava K.',
      message: 'Are both roots on the x-axis?',
      timestamp: DateTime(2026, 10, 19, 16, 24),
    ),
    ChatMessage(
      id: '2',
      userId: 'off',
      displayName: 'Jonah M.',
      message: 'I found x = 2 and x = 3.',
      timestamp: DateTime(2026, 10, 19, 16, 25),
    ),
  ];
  @override
  Stream<List<ChatMessage>> get messageSnapshots => const Stream.empty();
  @override
  Stream<ChatConnectionState> get states => const Stream.empty();
  @override
  Stream<ChatEvent> get events => const Stream.empty();
  @override
  Future<void> sendMessage(String message) async {}
  @override
  Future<void> dispose() async {}
}

class _PreviewRenderer extends MediaTrackRenderer {
  const _PreviewRenderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      track.isScreenShare
      ? const ColoredBox(
          color: Color(0xFF191F2D),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                'LESSON EXAMPLE\n\nfunction findRoots(a, b, c) {\n  const d = b * b - 4 * a * c;\n  return [\n    (-b + Math.sqrt(d)) / (2 * a),\n    (-b - Math.sqrt(d)) / (2 * a),\n  ];\n}\n\nfindRoots(1, -5, 6);\n// [3, 2]',
                style: TextStyle(
                  color: Color(0xFFDBE6F5),
                  fontSize: 16,
                  height: 1.8,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        )
      : ColoredBox(
          color: const Color(0xFFC4CDDA),
          child: Center(
            child: RealtimeAvatar(
              name: track.isLocal ? 'Ms. Rivera' : 'Ava',
              size: 180,
            ),
          ),
        );
}

// Local devices are fixture handles; no platform capture is opened.
class _PreviewDevices implements MediaLocalPreviewSession {
  MediaLocalPreviewSettings _settings = const MediaLocalPreviewSettings();
  @override
  String get providerId => 'preview';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  MediaVideoTrack? get cameraTrack => null;
  @override
  MediaTrackRenderer get renderer => const _PreviewRenderer();
  @override
  MediaLocalPreviewSettings get settings => _settings;
  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _settings = _settings.copyWith(microphoneEnabled: enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _settings = _settings.copyWith(cameraEnabled: enabled);
  }

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async => [
    for (final device in const [
      MediaDevice(
        id: 'camera',
        label: 'Built-in camera',
        kind: MediaDeviceKind.camera,
      ),
      MediaDevice(
        id: 'mic',
        label: 'Studio microphone',
        kind: MediaDeviceKind.microphone,
      ),
      MediaDevice(
        id: 'speaker',
        label: 'Speakers',
        kind: MediaDeviceKind.audioOutput,
      ),
    ])
      if (kinds == null || kinds.contains(device.kind)) device,
  ];
  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _settings = switch (device.kind) {
      MediaDeviceKind.camera => _settings.copyWith(camera: device),
      MediaDeviceKind.microphone => _settings.copyWith(microphone: device),
      MediaDeviceKind.audioOutput => _settings.copyWith(audioOutput: device),
    };
  }

  @override
  Future<void> dispose() async {}
}
