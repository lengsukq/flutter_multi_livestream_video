import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Renderable Agora camera track represented by channel + numeric UID.
class AgoraMediaVideoTrack extends MediaVideoTrack {
  const AgoraMediaVideoTrack({
    required this.engine,
    required this.channelId,
    required this.uid,
    required this.local,
    this.frameWidth = 0,
    this.frameHeight = 0,
  });

  final agora.RtcEngine engine;
  final String channelId;
  final int uid;
  final bool local;
  final int frameWidth;
  final int frameHeight;

  @override
  String get id => 'agora:$channelId:$uid:camera';

  @override
  String get participantId => uid.toString();

  @override
  bool get isLocal => local;

  @override
  bool get isScreenShare => false;

  @override
  int get width => frameWidth;

  @override
  int get height => frameHeight;
}
