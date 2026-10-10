import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_livekit/src/livekit_local_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'LiveKit preview starts without opening microphone or camera capture',
    () async {
      final preview = await LiveKitLocalPreviewSession.create(
        role: MediaRole.participant,
      );
      expect(preview.settings.microphoneEnabled, isFalse);
      expect(preview.settings.cameraEnabled, isFalse);
      expect(preview.cameraTrack, isNull);
      expect(preview.capabilities.canPublishVideo, isTrue);
      await preview.dispose();
    },
  );
}
