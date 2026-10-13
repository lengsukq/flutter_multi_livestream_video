import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

class ClassroomTimer {
  const ClassroomTimer({required this.title, required this.endsAt});
  final String title;
  final DateTime endsAt;
  Duration remaining({DateTime? now}) {
    final duration = endsAt.difference(now ?? DateTime.now());
    return duration.isNegative ? Duration.zero : duration;
  }

  factory ClassroomTimer.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => ClassroomTimer._fromJsonUnchecked(value));
  factory ClassroomTimer._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomTimer(
        title: JsonReader(value).required<String>('title'),
        endsAt: JsonReader(value).dateTime('endsAt'),
      );
}
