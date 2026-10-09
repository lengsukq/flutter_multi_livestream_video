import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

/// Classroom control-plane adapter. Notifications only trigger authoritative reads.
class ClassroomWhiteboardRepository implements WhiteboardRepository {
  ClassroomWhiteboardRepository(this.classroom);
  final ClassroomSession classroom;
  WhiteboardState _board() =>
      classroom.state?.tools?.content?.whiteboard ??
      (throw UnsupportedError(
        'The backend does not declare whiteboard support',
      ));
  @override
  Stream<WhiteboardState> get states => classroom.states
      .where((s) => s.tools?.content != null)
      .map((s) => s.tools!.content!.whiteboard);
  @override
  Future<WhiteboardState> snapshot() async {
    if (classroom.state == null) {
      await classroom.start();
    } else {
      await classroom.refresh();
    }
    return _board();
  }

  @override
  Future<WhiteboardState> action(WhiteboardCommand command) async {
    try {
      await classroom.execute(ClassroomCommand.whiteboard(command));
    } catch (error, stack) {
      try {
        await classroom.refresh();
      } catch (_) {}
      Error.throwWithStackTrace(error, stack);
    }
    return _board();
  }

  @override
  Future<void> close() async {} // Classroom lifetime belongs to the room.
}
