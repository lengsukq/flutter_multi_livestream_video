import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/design_capture.dart';
import 'support/meeting_sharing_fixture.dart';

void main() {
  setUpAll(initializeDesignCapture);
  for (final scene in [
    'more',
    'share',
    'background',
    'recording-layout',
    'recording-result',
    'host-tools',
    'drawing-color',
    'publish',
  ]) {
    testWidgets(
      'SDK secondary $scene remains usable across narrow and enlarged layouts',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final recorder = _Recorder();
        final fixture = await MeetingSharingFixture.create(
          mode: SharedContentMode.whiteboard,
          localShare: true,
          role: MediaRole.host,
          cloudRecording: recorder,
        );
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
            tester.view.physicalSize = size;
            late BuildContext launcher;
            var chosen = false;
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
                  home: RealtimeRoomUiScope(
                    room: fixture.room,
                    child: Builder(
                      builder: (context) {
                        launcher = context;
                        return Scaffold(
                          appBar: AppBar(
                            title: const Text('SDK component preview'),
                          ),
                          body: Center(
                            child: switch (scene) {
                              'more' => RealtimeDockMoreButton(
                                items: [
                                  RealtimeDockMoreItem(
                                    icon: Icons.cameraswitch_outlined,
                                    title: 'Switch camera',
                                    onTap: () => chosen = true,
                                  ),
                                  RealtimeDockMoreItem(
                                    icon: Icons.blur_on_outlined,
                                    title: 'Background effects',
                                    onTap: () {},
                                  ),
                                  RealtimeDockMoreItem(
                                    icon: Icons.radio_button_checked,
                                    title: 'Stop recording',
                                    subtitle: 'Recording',
                                    isDanger: true,
                                    isActive: true,
                                    onTap: () {},
                                  ),
                                  RealtimeDockMoreItem(
                                    icon: Icons.download_outlined,
                                    title: 'Recording results',
                                    onTap: () {},
                                  ),
                                  RealtimeDockMoreItem(
                                    icon: Icons.speaker_outlined,
                                    title: 'Audio output',
                                    enabled: false,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                              'share' =>
                                const RealtimeDockSharedContentButton(),
                              'background' =>
                                const RealtimeBackgroundEffectsButton(),
                              'publish' => ClassroomToolsPanel(
                                classroom: fixture.room.classroom!,
                              ),
                              _ => const SizedBox.shrink(),
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            switch (scene) {
              case 'more':
                await tester.tap(find.byType(RealtimeDockMoreButton));
              case 'share':
                await tester.tap(find.byType(RealtimeDockSharedContentButton));
              case 'background':
                await tester.tap(find.byType(RealtimeBackgroundEffectsButton));
              case 'recording-layout':
                unawaited(
                  showRealtimeRecordingLayoutPicker(launcher, fixture.room),
                );
              case 'recording-result':
                unawaited(
                  showDialog<void>(
                    context: launcher,
                    builder: (_) =>
                        RealtimeRecordingResultDialog(room: fixture.room),
                  ),
                );
              case 'host-tools':
                unawaited(showRealtimeHostToolsBottomSheet(launcher));
              case 'drawing-color':
                unawaited(
                  showWhiteboardColorPicker(launcher, initialColor: 0xff0b7f72),
                );
              case 'publish':
                await tester.tap(find.text('Announcement'));
            }
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$scene at $size x$scale',
            );
            if (scale == 1 && [390.0, 768.0, 1440.0].contains(size.width)) {
              await captureDesign(
                tester,
                'secondary-$scene-${size.width.toInt()}',
              );
            }
            if (scene == 'more') {
              await tester.ensureVisible(find.text('Switch camera'));
              await tester.tap(find.text('Switch camera'));
              await tester.pumpAndSettle();
              expect(chosen, isTrue);
            } else {
              // Modal navigation always permits leaving without activating a capability.
              Navigator.pop(launcher);
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        }
        await tester.runAsync(fixture.room.dispose);
      },
    );
  }

  testWidgets(
    'recording failure can retry without offering a download prematurely',
    (tester) async {
      final recorder = _Recorder()..fail = true;
      final fixture = await MeetingSharingFixture.create(
        cloudRecording: recorder,
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: designTestTheme(),
          home: RealtimeRecordingResultDialog(room: fixture.room),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.download), findsNothing);
      recorder.fail = false;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('finalizing'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.room.dispose);
    },
  );
}

class _Recorder implements MediaCloudRecordingSession {
  bool fail = false;
  @override
  Future<RecordingResult> queryCloudRecording() async {
    if (fail) {
      throw const RealtimeException(
        code: RealtimeErrorCode.network,
        message: 'recording.query',
      );
    }
    return RecordingResult(
      mode: RecordingMode.cloud,
      recordingId: 'preview-recording',
      taskState: RecordingTaskState.processing,
      metadata: const {
        'supportedLayouts': ['grid', 'featuredParticipant', 'activeSpeaker'],
      },
    );
  }

  @override
  Future<RecordingResult> startCloudRecording(RecordingOptions options) =>
      queryCloudRecording();
  @override
  Future<RecordingResult> stopCloudRecording() => queryCloudRecording();
  @override
  Future<Uri> cloudRecordingDownloadUrl() async =>
      Uri.parse('https://example.invalid/recording');
  @override
  void dispose() {}
}
