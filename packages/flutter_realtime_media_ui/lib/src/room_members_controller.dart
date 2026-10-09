import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class RoomMuteResult {
  RoomMuteResult(Map<MediaParticipant, Object> failures, this.completed)
    : failures = Map.unmodifiable(failures);
  final Map<MediaParticipant, Object> failures;
  final bool completed;
}

/// Executes member operations without retaining a widget or BuildContext.
class RoomMembersController {
  bool _busy = false;
  Future<RoomMuteResult> mute(
    MediaRoomSession room,
    List<MediaParticipant> targets, {
    required bool Function() isCurrent,
  }) async {
    if (_busy) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Member management is already running.',
      );
    }
    _busy = true;
    final failures = <MediaParticipant, Object>{};
    try {
      for (final participant in targets) {
        if (!isCurrent()) return RoomMuteResult(failures, false);
        try {
          await room.muteParticipant(participant.id);
        } catch (error, stack) {
          failures[participant] = normalizeRealtimeException(
            error,
            domain: 'media',
            operation: 'muteParticipant',
            stackTrace: stack,
          );
        }
      }
      return RoomMuteResult(failures, isCurrent());
    } finally {
      _busy = false;
    }
  }
}
