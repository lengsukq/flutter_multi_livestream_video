import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class IvsMediaVideoTrack extends MediaVideoTrack {
  const IvsMediaVideoTrack({
    required this.userId,
    required this.local,
    this.generation = 0,
  });

  final String userId;
  final bool local;
  final int generation;

  @override
  String get id => 'ivs:$userId:camera:$generation';
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
