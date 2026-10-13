import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'classroom_activity_kind.dart';

class ClassroomActivity {
  ClassroomActivity({
    required this.id,
    required this.kind,
    required this.title,
    required List<String> options,
    required this.closed,
    this.responseCount = 0,
    this.selfAnswer,
    this.correctOption,
    List<int>? counts,
    Map<String, int> answers = const {},
  }) : options = List.unmodifiable(options),
       counts = counts == null ? null : List.unmodifiable(counts),
       answers = Map.unmodifiable(answers);
  final String id, title;
  final ClassroomActivityKind kind;
  final List<String> options;
  final bool closed;
  final int responseCount;
  // Intentionally absent for students while a quiz remains open.
  final int? correctOption, selfAnswer;
  final List<int>? counts;
  final Map<String, int> answers;
  factory ClassroomActivity.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => ClassroomActivity._fromJsonUnchecked(value));
  factory ClassroomActivity._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomActivity(
        id: JsonReader(value).required<String>('id'),
        kind: JsonReader(value).enumValue('kind', ClassroomActivityKind.values),
        title: JsonReader(value).required<String>('title'),
        options: JsonReader(value).list<String>('options'),
        closed: JsonReader(value).required<bool>('closed'),
        responseCount: JsonReader(value).optional<int>('responseCount') ?? 0,
        selfAnswer: JsonReader(value).optional<int>('selfAnswer'),
        correctOption: JsonReader(value).optional<int>('correctOption'),
        counts: value['counts'] == null
            ? null
            : JsonReader(value).list<int>('counts'),
        answers: Map.unmodifiable(
          (value['answers'] as Map? ?? {}).cast<String, int>(),
        ),
      );
}
