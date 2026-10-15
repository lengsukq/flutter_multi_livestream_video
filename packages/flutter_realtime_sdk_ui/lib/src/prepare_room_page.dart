import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';

/// Applies the same Pre-Join choices for both built-in room pages.
Future<void> prepareRoomPage(
  RealtimeRoom room,
  MediaLocalPreviewSettings? settings, {
  required bool Function() isCurrent,
}) async {
  if (settings == null || room.media.role == MediaRole.viewer) return;
  await room.prepareVideoEffects(settings);
  if (!isCurrent()) return;
  await InitialMediaSettingsController().apply(
    session: room.media.session,
    effects: room,
    setCameraEnabled: (enabled) async {
      if (room.media.snapshot.localVideoEnabled != enabled) {
        await room.setCameraEnabled(enabled);
      }
    },
    settings: settings,
    isCurrent: isCurrent,
    canEnableMicrophone: () {
      final classroom = room.classroom;
      if (classroom == null) return true;
      final state = classroom.state;
      if (state?.isTeacher == true || room.media.roomOwnerCredential != null) {
        return true;
      }
      return state?.students.any(
            (student) => student.userId == state.selfUserId && student.canSpeak,
          ) ??
          false;
    },
    onError: (error) => throw error,
  );
}
