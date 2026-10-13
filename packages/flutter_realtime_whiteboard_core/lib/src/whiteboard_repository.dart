import 'whiteboard_command.dart';
import 'dart:async';
import 'whiteboard_state.dart';

abstract interface class WhiteboardRepository {
  Stream<WhiteboardState> get states;
  Future<WhiteboardState> snapshot();
  Future<WhiteboardState> action(WhiteboardCommand command);
  Future<void> close();
}
