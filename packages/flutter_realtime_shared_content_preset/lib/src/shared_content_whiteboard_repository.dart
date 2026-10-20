import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'shared_content_command.dart';
import 'shared_content_session.dart';

class SharedContentWhiteboardRepository implements WhiteboardRepository {
  SharedContentWhiteboardRepository(this.session);
  final SharedContentSession session;
  WhiteboardState get _board => session.state!.whiteboard;
  @override
  Stream<WhiteboardState> get states => session.states
      .where((state) => state != null)
      .map((state) => state!.whiteboard);
  @override
  Future<WhiteboardState> snapshot() async {
    await session.refresh();
    return _board;
  }

  @override
  Future<WhiteboardState> action(WhiteboardCommand command) async {
    await session.execute(SharedContentCommand.whiteboard(command));
    return _board;
  }

  @override
  Future<void> close() async {}
}
