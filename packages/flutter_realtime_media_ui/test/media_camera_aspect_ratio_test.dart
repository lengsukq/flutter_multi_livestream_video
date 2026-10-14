import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates a camera that reports stale landscape track metadata (640x360)
/// but decodes actual portrait frames (9:16), as happens during rotation.
class _PortraitCameraTrack extends MediaVideoTrack {
  const _PortraitCameraTrack({this.screenShare = false});

  final bool screenShare;

  @override
  String get id => 'portrait-camera';
  @override
  String get participantId => 'remote';
  @override
  bool get isLocal => false;
  @override
  bool get isScreenShare => screenShare;
  @override
  int get width => 640;
  @override
  int get height => 360;
}

class _PortraitVideoRenderer extends MediaTrackRenderer {
  const _PortraitVideoRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      buildViewWithFit(context, track);

  @override
  Widget buildViewWithFit(
    BuildContext context,
    MediaVideoTrack track, {
    BoxFit fit = BoxFit.contain,
  }) => Center(
    child: AspectRatio(
      aspectRatio: 9 / 16,
      child: const ColoredBox(
        key: ValueKey('actual-portrait-video'),
        color: Colors.black,
      ),
    ),
  );
}

void main() {
  testWidgets(
    'camera fills available stage height despite stale track dimensions',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 960,
                height: 600,
                child: MediaParticipantTile(
                  borderless: true,
                  renderer: _PortraitVideoRenderer(),
                  participant: MediaParticipant(
                    id: 'remote',
                    displayName: 'Portrait caller',
                    isVideoEnabled: true,
                    videoTrack: _PortraitCameraTrack(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final video = find.byKey(const ValueKey('actual-portrait-video'));
      expect(video, findsOneWidget);
      expect(tester.getSize(video).height, closeTo(600, 1));
      expect(
        find.descendant(
          of: find.byType(MediaParticipantTile),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('screen sharing retains track-dimension based contain behavior', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 960,
              height: 600,
              child: MediaTrackView(
                renderer: _PortraitVideoRenderer(),
                track: _PortraitCameraTrack(screenShare: true),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FittedBox), findsOneWidget);
    final video = find.byKey(const ValueKey('actual-portrait-video'));
    expect(tester.getSize(video).height, lessThan(600));
    expect(tester.takeException(), isNull);
  });
}
