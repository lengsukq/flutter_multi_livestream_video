import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'processed_video_source.dart';

class ProcessedVideoTrack extends MediaVideoTrack {
  const ProcessedVideoTrack({
    required this.source,
    this.participantId = 'local-effects-preview',
  });

  final ProcessedVideoSource source;

  @override
  String get id => 'effects:${source.id}';

  @override
  final String participantId;

  @override
  bool get isLocal => true;

  @override
  bool get isScreenShare => false;

  @override
  int get width => source.width;

  @override
  int get height => source.height;
}
