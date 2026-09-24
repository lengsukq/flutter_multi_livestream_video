import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'livekit_join_info.dart';
import 'livekit_media_session.dart';

/// Registers LiveKit as a provider for [MediaClient].
class LiveKitSessionFactory implements MediaSessionFactory {
  const LiveKitSessionFactory();

  @override
  String get providerId => LiveKitJoinInfo.providerIdValue;

  @override
  Set<MediaRole> get supportedRoles => const {
    MediaRole.participant,
    MediaRole.host,
    MediaRole.viewer,
  };

  @override
  LiveKitJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      LiveKitJoinInfo.fromBackendResponse(json);

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo is! LiveKitJoinInfo) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'LiveKitSessionFactory requires LiveKitJoinInfo.',
        providerId: LiveKitJoinInfo.providerIdValue,
      );
    }
    return switch (joinInfo.role) {
      MediaRole.participant => LiveKitInteractiveSession(),
      MediaRole.host => LiveKitHostSession(),
      MediaRole.viewer => LiveKitViewerSession(),
    };
  }
}
