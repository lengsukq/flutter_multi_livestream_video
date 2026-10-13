import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

class ClassroomHomework {
  const ClassroomHomework({
    required this.id,
    required this.title,
    required this.instructions,
    this.dueAt,
  });
  final String id, title, instructions;
  final DateTime? dueAt;
  factory ClassroomHomework.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => ClassroomHomework._fromJsonUnchecked(value));
  factory ClassroomHomework._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomHomework(
        id: JsonReader(value).required<String>('id'),
        title: JsonReader(value).required<String>('title'),
        instructions: JsonReader(value).required<String>('instructions'),
        dueAt: value['dueAt'] == null
            ? null
            : JsonReader(value).dateTime('dueAt'),
      );
}
