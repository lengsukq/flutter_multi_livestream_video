import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

class ClassroomNotice {
  const ClassroomNotice({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
  });
  final String id, kind, text;
  final DateTime createdAt;
  bool get isFocusReminder => kind == 'focus';
  factory ClassroomNotice.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => ClassroomNotice._fromJsonUnchecked(value));
  factory ClassroomNotice._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomNotice(
        id: JsonReader(value).required<String>('id'),
        kind: JsonReader(value).required<String>('kind'),
        text: JsonReader(value).required<String>('text'),
        createdAt: JsonReader(value).dateTime('createdAt'),
      );
}
