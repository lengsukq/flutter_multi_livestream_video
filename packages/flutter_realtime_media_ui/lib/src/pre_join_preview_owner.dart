import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Single owner of a Pre-Join media preview and its optional failure stream.
///
/// UI, device selectors and SDK entry code can all request release without
/// disposing the same camera/microphone capture twice.
class PreJoinPreviewOwner {
  MediaLocalPreviewSession? _session;
  StreamSubscription<RealtimeException>? _failures;
  Future<void>? _releaseFuture;

  MediaLocalPreviewSession? get session => _session;

  void bind(
    MediaLocalPreviewSession? preview, {
    required void Function(RealtimeException error) onFailure,
  }) {
    if (_session != null || _failures != null || _releaseFuture != null) {
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

  Future<void> release() {
    final inFlight = _releaseFuture;
    if (inFlight != null) return inFlight;
    final failures = _failures;
    final preview = _session;
    // Clear ownership first, so racing leave/dispose cannot double-release.
    _session = null;
    _failures = null;
    if (failures == null && preview == null) return Future<void>.value();
    final releasing = _releaseAssets(failures, preview);
    _releaseFuture = releasing;
    // Concurrent callers must observe the same release completion before a
    // replacement preview can be bound; failures still reach their caller.
    unawaited(
      releasing.then<void>(
        (_) => _releaseFuture = null,
        onError: (Object _, StackTrace __) => _releaseFuture = null,
      ),
    );
    return releasing;
  }

  Future<void> _releaseAssets(
    StreamSubscription<RealtimeException>? failures,
    MediaLocalPreviewSession? preview,
  ) {
    if (failures != null) {
      return failures.cancel().then((_) => preview?.dispose());
    }
    return preview?.dispose() ?? Future<void>.value();
  }

  void dispose() => unawaited(release());
}
