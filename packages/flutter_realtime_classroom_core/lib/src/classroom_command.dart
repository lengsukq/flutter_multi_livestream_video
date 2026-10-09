import 'dart:convert';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

enum ClassroomAction {
  handRaise('hand.raise'),
  handLower('hand.lower'),
  speakGrant('speak.grant'),
  speakRevoke('speak.revoke'),
  questionAsk('question.ask'),
  questionAnswer('question.answer'),
  questionResolve('question.resolve'),
  feedbackSend('feedback.send');

  const ClassroomAction(this.wireName);
  final String wireName;
}

enum ClassroomToolAction {
  noticePublish('notice.publish'),
  homeworkPublish('homework.publish'),
  materialShare('material.share'),
  timerStart('timer.start'),
  timerStop('timer.stop'),
  activityPublish('activity.publish'),
  activityAnswer('activity.answer'),
  activityClose('activity.close'),
  annotationSource('annotation.source'),
  annotationPresentation('annotation.presentation'),
  annotationBegin('annotation.begin'),
  annotationAppend('annotation.append'),
  annotationUndo('annotation.undo'),
  annotationClear('annotation.clear'),
  contentMode('content.mode');

  const ClassroomToolAction(this.wireName);
  final String wireName;
}

class ClassroomCommand {
  ClassroomCommand(this.action, [Map<String, String> arguments = const {}])
    : arguments = Map.unmodifiable(arguments),
      tool = null,
      eventId = null,
      payload = const {};
  ClassroomCommand.tool(
    ClassroomToolAction action,
    Map<String, Object?> payload, {
    this.eventId,
  }) : action = null,
       tool = action.wireName,
       arguments = const {},
       payload = freezeJson(payload) as Map<String, Object?>;
  ClassroomCommand.whiteboard(WhiteboardCommand command)
    : action = null,
      tool = 'whiteboard.${command.action.wireName}',
      arguments = const {},
      eventId = command.eventId,
      payload = freezeJson(command.payload) as Map<String, Object?>;
  final ClassroomAction? action;
  final Map<String, String> arguments;
  final String? tool, eventId;
  final Map<String, Object?> payload;
  String get wireName => tool == null ? action!.wireName : 'tool.$tool';
  Map<String, String> toWireData() => tool == null
      ? arguments
      : {
          'payload': jsonEncode(payload),
          if (eventId != null) 'eventId': eventId!,
        };
}
