import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'classroom_question_status.dart';

class ClassroomQuestion {
  const ClassroomQuestion({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.status,
    required this.createdAt,
    this.answer,
    this.avatarUrl,
  });
  final String id, userId, displayName, text;
  final String? avatarUrl;
  final ClassroomQuestionStatus status;
  final DateTime createdAt;
  final String? answer;
  factory ClassroomQuestion.fromJson(Map<String, dynamic> data) =>
      JsonReader(data).decode(() => ClassroomQuestion._fromJsonUnchecked(data));
  factory ClassroomQuestion._fromJsonUnchecked(Map<String, dynamic> data) =>
      ClassroomQuestion(
        id: JsonReader(data).required<String>('id'),
        userId: JsonReader(data).required<String>('userId'),
        displayName: JsonReader(data).optional<String>('displayName') ?? '',
        avatarUrl: JsonReader(data).optional<String>('avatarUrl'),
        text: JsonReader(data).required<String>('text'),
        status: JsonReader(
          data,
        ).enumValue('status', ClassroomQuestionStatus.values),
        createdAt: JsonReader(data).dateTime('createdAt'),
        answer: JsonReader(data).optional<String>('answer'),
      );
}
