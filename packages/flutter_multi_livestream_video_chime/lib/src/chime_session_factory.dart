import 'package:flutter/foundation.dart';
import 'package:flutter_aws_chime/flutter_aws_chime.dart' as chime;
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';

import 'chime_join_info.dart';
import 'chime_media_session.dart';

typedef ChimeMeetingSessionFactory = chime.ChimeMeetingSession Function();

/// Registers the existing flutter_aws_chime implementation with [MediaClient].
class ChimeSessionFactory implements MediaSessionFactory {
  ChimeSessionFactory({ChimeMeetingSessionFactory? sessionFactory})
    : _sessionFactory = sessionFactory ?? chime.ChimeMeetingSession.new;

  final ChimeMeetingSessionFactory _sessionFactory;

  @override
  String get providerId => ChimeJoinInfo.providerIdValue;

  @override
  Set<MediaRole> get supportedRoles => const {MediaRole.participant};

  @override
  bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  ChimeJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      ChimeJoinInfo.fromBackendResponse(json);

  @override
  ChimeMediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo is! ChimeJoinInfo || joinInfo.role != MediaRole.participant) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'ChimeSessionFactory requires participant ChimeJoinInfo.',
        providerId: ChimeJoinInfo.providerIdValue,
      );
    }
    return ChimeMediaSession(session: _sessionFactory());
  }
}
