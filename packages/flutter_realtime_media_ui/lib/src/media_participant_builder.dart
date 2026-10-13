import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

typedef MediaParticipantBuilder =
    Widget Function(
      BuildContext context,
      MediaParticipant participant,
      MediaTrackRenderer renderer,
    );
