import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'provider_web_session_base.dart';

class ProviderWebParticipantSession extends ProviderWebSessionBase
    implements
        InteractiveMediaSession,
        MediaBackgroundEffectsController,
        ProcessedVideoSink {
  ProviderWebParticipantSession({
    required super.providerId,
    required super.role,
    required super.sessionId,
    required super.joinPayload,
    required super.capabilities,
  });

  @override
  bool supportsProcessedVideoSource(ProcessedVideoSource source) =>
      supportsProcessedVideoSourceInternal(source);

  @override
  Future<void> attachProcessedVideoSource(ProcessedVideoSource source) =>
      attachProcessedVideoSourceInternal(source);

  @override
  Future<void> detachProcessedVideoSource() =>
      detachProcessedVideoSourceInternal();
}
