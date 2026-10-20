import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

/// Invoked after preview release; the application connects and navigates.
/// A failed entry remains on the page and can be retried with the same choices.
typedef RealtimePreJoinEnter =
    Future<void> Function(
      BuildContext context,
      MediaLocalPreviewSettings settings,
    );

/// Variant of [RealtimePreJoinEnter] that also carries the entry intent.
///
/// Hosts use this to start screen sharing after the connection is established;
/// the SDK never changes the room on its own.
typedef RealtimePreJoinEnterWithIntent =
    Future<void> Function(
      BuildContext context,
      MediaLocalPreviewSettings settings,
      RealtimePreJoinJoinIntent intent,
    );
