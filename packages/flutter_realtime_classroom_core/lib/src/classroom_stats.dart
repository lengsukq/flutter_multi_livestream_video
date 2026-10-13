import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

class ClassroomStats {
  const ClassroomStats({
    this.onlineCount = 0,
    this.onlineStudents = 0,
    this.studentsTotal = 0,
    this.handsRaised = 0,
    this.pendingQuestions = 0,
    this.questionsTotal = 0,
    this.speakGrants = 0,
    this.chatMessages = 0,
    this.handRaisesTotal = 0,
  });
  final int onlineCount, handsRaised, pendingQuestions, questionsTotal;
  final int onlineStudents, studentsTotal;
  final int speakGrants, chatMessages;
  final int handRaisesTotal;
  factory ClassroomStats.fromJson(Map<String, dynamic> data) =>
      JsonReader(data).decode(() => ClassroomStats._fromJsonUnchecked(data));
  factory ClassroomStats._fromJsonUnchecked(Map<String, dynamic> data) =>
      ClassroomStats(
        onlineCount: JsonReader(data).optional<int>('onlineCount') ?? 0,
        onlineStudents: JsonReader(data).optional<int>('onlineStudents') ?? 0,
        studentsTotal: JsonReader(data).optional<int>('studentsTotal') ?? 0,
        handsRaised: JsonReader(data).optional<int>('handsRaised') ?? 0,
        pendingQuestions:
            JsonReader(data).optional<int>('pendingQuestions') ?? 0,
        questionsTotal: JsonReader(data).optional<int>('questionsTotal') ?? 0,
        speakGrants: JsonReader(data).optional<int>('speakGrants') ?? 0,
        chatMessages: JsonReader(data).optional<int>('chatMessages') ?? 0,
        handRaisesTotal: JsonReader(data).optional<int>('handRaisesTotal') ?? 0,
      );
  ClassroomStats withChatMessages(int count) => ClassroomStats(
    onlineCount: onlineCount,
    onlineStudents: onlineStudents,
    studentsTotal: studentsTotal,
    handsRaised: handsRaised,
    pendingQuestions: pendingQuestions,
    questionsTotal: questionsTotal,
    speakGrants: speakGrants,
    chatMessages: count,
    handRaisesTotal: handRaisesTotal,
  );
}
