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

/// A PlatformView / Texture-like renderer that just fills its layout bounds.
/// Without the outer fitted geometry, decoded 16:9 content gets distorted.
class _RawNativeRenderer extends MediaTrackRenderer {
  const _RawNativeRenderer();

  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const ColoredBox(key: ValueKey('raw-native-camera'), color: Colors.black);
}

class _PortraitVideoRenderer extends MediaTrackRenderer {
  const _PortraitVideoRenderer();

  @override
  bool handlesVideoFit(MediaVideoTrack track) => true;

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
  testWidgets('portrait meeting stage never stretches a raw landscape camera', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(470, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 430,
              height: 750,
              child: MediaParticipantTile(
                borderless: true,
                renderer: _RawNativeRenderer(),
                participant: MediaParticipant(
                  id: 'local',
                  displayName: 'Local',
                  isLocal: true,
                  isVideoEnabled: true,
                  videoTrack: _PortraitCameraTrack(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final view = find.byKey(const ValueKey('raw-native-camera'));
    final fitted = find.descendant(
      of: find.byType(MediaParticipantTile),
      matching: find.byType(FittedBox),
    );
    expect(fitted, findsOneWidget);
    final rect = tester.getRect(view);
    expect(rect.width, closeTo(430, 1));
    expect(rect.height, closeTo(430 * 360 / 640, 1));
    expect(rect.width / rect.height, closeTo(16 / 9, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cover crops a raw landscape camera without distortion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(470, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 430,
              height: 750,
              child: MediaParticipantTile(
                borderless: true,
                fit: BoxFit.cover,
                renderer: _RawNativeRenderer(),
                participant: MediaParticipant(
                  id: 'local',
                  displayName: 'Local',
                  isVideoEnabled: true,
                  videoTrack: _PortraitCameraTrack(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(
      find.byKey(const ValueKey('raw-native-camera')),
    );
    expect(rect.height, closeTo(750, 1));
    expect(rect.width / rect.height, closeTo(16 / 9, .01));
    expect(tester.takeException(), isNull);
  });
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
