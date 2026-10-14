import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

void main() {
  testWidgets('self view and audience view use the same video orientation', (
    tester,
  ) async {
    for (final local in [true, false]) {
      late lk.VideoTrackRenderer rendered;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            rendered =
                const LiveKitTrackRenderer().buildViewWithFit(
                      context,
                      LiveKitMediaVideoTrack(
                        liveKitTrack: _Track(),
                        id: 'camera',
                        participantId: 'host',
                        isLocal: local,
                        isScreenShare: false,
                      ),
                      fit: BoxFit.cover,
                    )
                    as lk.VideoTrackRenderer;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(rendered.mirrorMode, lk.VideoViewMirrorMode.off);
      expect(rendered.fit, lk.VideoViewFit.cover);
    }
  });
}

class _Track extends Fake implements lk.VideoTrack {}
