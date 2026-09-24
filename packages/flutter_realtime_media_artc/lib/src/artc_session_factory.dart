import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'artc_engine.dart';
import 'artc_join_info.dart';
import 'artc_media_session.dart';

/// Creates optional Alibaba Cloud ARTC sessions without affecting other adapters.
class ArtcSessionFactory implements MediaSessionFactory {
  const ArtcSessionFactory({this.engineFactory = createNativeArtcEngine});

  /// Native factory defaults to ARTC's singleton engine. Tests may inject a fake.
  final ArtcEngineFactory engineFactory;

  @override
  String get providerId => ArtcJoinInfo.providerIdValue;

  @override
  Set<MediaRole> get supportedRoles => const {
    MediaRole.participant,
    MediaRole.host,
    MediaRole.viewer,
  };

  @override
  bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  ArtcJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      ArtcJoinInfo.fromJson(json);

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo.providerId != providerId ||
        !supportedRoles.contains(joinInfo.role)) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'ARTC session cannot be created for this provider or role.',
        providerId: ArtcJoinInfo.providerIdValue,
      );
    }
    return switch (joinInfo.role) {
      MediaRole.participant => ArtcParticipantSession(
        engineFactory: engineFactory,
      ),
      MediaRole.host => ArtcBroadcastHostSession(engineFactory: engineFactory),
      MediaRole.viewer => ArtcBroadcastViewerSession(
        engineFactory: engineFactory,
      ),
    };
  }
}
