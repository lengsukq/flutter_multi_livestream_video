import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

class ClassroomMaterial {
  const ClassroomMaterial({
    required this.id,
    required this.title,
    required this.url,
  });
  final String id, title, url;
  factory ClassroomMaterial.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => ClassroomMaterial._fromJsonUnchecked(value));
  factory ClassroomMaterial._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomMaterial(
        id: JsonReader(value).required<String>('id'),
        title: JsonReader(value).required<String>('title'),
        url: JsonReader(value).required<String>('url'),
      );
}
