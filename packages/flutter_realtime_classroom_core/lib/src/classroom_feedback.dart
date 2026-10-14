import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'classroom_feedback_kind.dart';

class ClassroomFeedback {
  const ClassroomFeedback({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.kind,
    required this.createdAt,
    this.avatarUrl,
  });
  final String id, userId, displayName;
  final String? avatarUrl;
  final ClassroomFeedbackKind kind;
  final DateTime createdAt;

  factory ClassroomFeedback.fromJson(Map<String, dynamic> data) =>
      JsonReader(data).decode(
        () => ClassroomFeedback(
          id: JsonReader(data).required<String>('id'),
          userId: JsonReader(data).required<String>('userId'),
          displayName: JsonReader(data).optional<String>('displayName') ?? '',
          avatarUrl: JsonReader(data).optional<String>('avatarUrl'),
          kind: JsonReader(
            data,
          ).enumValue('kind', ClassroomFeedbackKind.values),
          createdAt: JsonReader(data).dateTime('createdAt'),
        ),
      );
}
