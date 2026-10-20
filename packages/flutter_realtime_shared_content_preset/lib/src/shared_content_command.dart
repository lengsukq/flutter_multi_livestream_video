import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

enum SharedContentAction {
  mode('content.mode'),
  source('annotation.source'),
  presentation('annotation.presentation'),
  begin('annotation.begin'),
  append('annotation.append'),
  undo('annotation.undo'),
  clear('annotation.clear');

  const SharedContentAction(this.wireName);
  final String wireName;
}

/// A shared-content command, independent of teaching roles and activities.
class SharedContentCommand {
  SharedContentCommand(this.action, Map<String, Object?> payload)
    : payload = freezeJson(payload) as Map<String, Object?>,
      whiteboard = null;
  SharedContentCommand.whiteboard(WhiteboardCommand command)
    : action = null,
      payload = const {},
      whiteboard = command;

  final SharedContentAction? action;
  final WhiteboardCommand? whiteboard;
  final Map<String, Object?> payload;
}
