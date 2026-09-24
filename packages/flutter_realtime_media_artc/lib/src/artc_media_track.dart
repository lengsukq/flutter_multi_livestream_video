import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Renderable ARTC camera track, identified by its provider user id.
class ArtcMediaVideoTrack extends MediaVideoTrack {
  const ArtcMediaVideoTrack({
    required this.userId,
    required this.local,
    this.generation = 0,
  });

  final String userId;
  final bool local;
  final int generation;

  @override
  String get id => 'artc:$userId:camera:$generation';

  @override
  String get participantId => userId;

  @override
  bool get isLocal => local;

  @override
  bool get isScreenShare => false;

  @override
  int get width => 0;

  @override
  int get height => 0;
}
