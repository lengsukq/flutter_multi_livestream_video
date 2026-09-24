import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'trtc_join_info.dart';
import 'trtc_media_session.dart';
import 'trtc_engine.dart';

/// Creates optional Tencent TRTC sessions without affecting other adapters.
class TrtcSessionFactory implements MediaSessionFactory {
  const TrtcSessionFactory({this.engineFactory = createNativeTrtcEngine});

  /// Native factory defaults to Tencent's singleton TRTC engine. Tests and
  /// specialized hosts may provide an in-memory implementation.
  final TrtcEngineFactory engineFactory;

  @override
  String get providerId => TrtcJoinInfo.providerIdValue;

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
  TrtcJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      TrtcJoinInfo.fromJson(json);

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo.providerId != providerId ||
        !supportedRoles.contains(joinInfo.role)) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'TRTC session cannot be created for this provider or role.',
        providerId: TrtcJoinInfo.providerIdValue,
      );
    }
    return switch (joinInfo.role) {
      MediaRole.participant => TrtcParticipantSession(
        engineFactory: engineFactory,
      ),
      MediaRole.host => TrtcHostSession(engineFactory: engineFactory),
      MediaRole.viewer => TrtcViewerSession(engineFactory: engineFactory),
    };
  }
}
