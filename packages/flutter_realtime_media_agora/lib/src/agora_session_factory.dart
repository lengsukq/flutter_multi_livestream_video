import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'agora_join_info.dart';
import 'agora_media_session.dart';

/// Registers Agora as a provider for MediaClient.
class AgoraSessionFactory implements MediaSessionFactory {
  const AgoraSessionFactory({this.engineFactory});
  final agora.RtcEngine Function()? engineFactory;

  @override
  String get providerId => AgoraJoinInfo.providerIdValue;

  @override
  Set<MediaRole> get supportedRoles => const {
    MediaRole.participant,
    MediaRole.host,
    MediaRole.viewer,
  };

  @override
  AgoraJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      AgoraJoinInfo.fromBackendResponse(json);

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo is! AgoraJoinInfo) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'AgoraSessionFactory requires AgoraJoinInfo.',
        providerId: AgoraJoinInfo.providerIdValue,
      );
    }
    return switch (joinInfo.role) {
      MediaRole.participant => AgoraInteractiveSession(
        engineFactory: engineFactory,
      ),
      MediaRole.host => AgoraHostSession(engineFactory: engineFactory),
      MediaRole.viewer => AgoraViewerSession(engineFactory: engineFactory),
    };
  }
}
