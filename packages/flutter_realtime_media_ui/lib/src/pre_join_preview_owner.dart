import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Single owner of a Pre-Join media preview and its optional failure stream.
///
/// UI, device selectors and SDK entry code can all request release without
/// disposing the same camera/microphone capture twice.
class PreJoinPreviewOwner {
  MediaLocalPreviewSession? _session;
  StreamSubscription<RealtimeException>? _failures;

  MediaLocalPreviewSession? get session => _session;

  void bind(
    MediaLocalPreviewSession? preview, {
    required void Function(RealtimeException error) onFailure,
  }) {
    if (_session != null || _failures != null) {
      throw StateError('Release the current local preview before rebinding.');
    }
    _session = preview;
    if (preview is MediaLocalPreviewFailureEvents) {
      final events = preview as MediaLocalPreviewFailureEvents;
      _failures = events.failures.listen((RealtimeException error) {
        if (identical(_session, preview)) onFailure(error);
      });
    }
  }

  Future<void> release() async {
    final failures = _failures;
    final preview = _session;
    // Clear ownership first, so racing leave/dispose cannot double-release.
    _session = null;
    _failures = null;
    await failures?.cancel();
    await preview?.dispose();
  }

  void dispose() => unawaited(release());
}
