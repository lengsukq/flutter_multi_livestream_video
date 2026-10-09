import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

enum WhiteboardAction {
  pageAdd('page.add'),
  pageSelect('page.select'),
  pageDelete('page.delete'),
  begin('begin'),
  append('append'),
  undo('undo'),
  clear('clear');

  const WhiteboardAction(this.wireName);
  final String wireName;
}

class WhiteboardCommand {
  WhiteboardCommand(
    this.action,
    Map<String, Object?> payload, {
    required this.eventId,
  }) : payload = freezeJson(payload) as Map<String, Object?>;
  final WhiteboardAction action;
  final Map<String, Object?> payload;
  final String eventId;
}
