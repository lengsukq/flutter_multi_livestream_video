import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'classroom_tools.dart';

enum ClassroomRole { teacher, student }

enum ClassroomQuestionStatus { pending, answered, resolved }

enum ClassroomNotificationKind {
  handRaised,
  questionAsked,
  questionAnswered,
  speakGranted,
  noticePublished,
  activityPublished,
  homeworkPublished,
  materialShared,
  timerChanged,
}

enum ClassroomStateEventKind {
  handRaised,
  handLowered,
  speakGranted,
  speakRevoked,
  questionAsked,
  questionAnswered,
  questionResolved,
  studentJoined,
  studentLeft,
}

/// Derived from authenticated state snapshots, never from untrusted RTC data.
class ClassroomStateEvent {
  const ClassroomStateEvent({
    required this.kind,
    required this.roomCode,
    required this.userId,
    required this.revision,
    this.questionId,
  });
  final ClassroomStateEventKind kind;
  final String roomCode;
  final String userId;
  final int revision;
  final String? questionId;
}

class ClassroomCapabilities {
  const ClassroomCapabilities({
    required this.canRaiseHand,
    required this.canAskQuestion,
    required this.canManageQuestions,
    required this.canGrantSpeak,
    required this.canViewRoster,
    this.enforcesMicrophone = false,
    this.canUseTools = false,
    this.canPublishTools = false,
  });
  final bool canRaiseHand, canAskQuestion, canManageQuestions, canGrantSpeak;
  final bool canViewRoster, enforcesMicrophone;
  final bool canUseTools, canPublishTools;
}

class ClassroomQuestion {
  const ClassroomQuestion({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.status,
    required this.createdAt,
    this.answer,
  });
  final String id, userId, displayName, text;
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
        text: JsonReader(data).required<String>('text'),
        status: JsonReader(
          data,
        ).enumValue('status', ClassroomQuestionStatus.values),
        createdAt: JsonReader(data).dateTime('createdAt'),
        answer: JsonReader(data).optional<String>('answer'),
      );
}

/// Optional low-latency hint transport. Revision hints are never trusted as
/// state or teacher authorization; only the repository's snapshot is used.
abstract interface class ClassroomRevisionTransport {
  Stream<int> get revisions;
  Future<void> publish(int revision);
  Future<void> dispose();
}

class ClassroomStudent {
  const ClassroomStudent({
    required this.userId,
    required this.participantId,
    required this.displayName,
    required this.online,
    required this.handRaised,
    required this.canSpeak,
    this.role = ClassroomRole.student,
    this.microphoneOn,
    this.cameraOn,
  });
  final String userId, participantId, displayName;
  final bool online, handRaised, canSpeak;
  final ClassroomRole role;
  // Null means the provider has not supplied media telemetry.
  final bool? microphoneOn, cameraOn;
  ClassroomStudent withMedia({bool? microphoneOn, bool? cameraOn}) =>
      ClassroomStudent(
        userId: userId,
        participantId: participantId,
        displayName: displayName,
        online: online,
        handRaised: handRaised,
        canSpeak: canSpeak,
        role: role,
        microphoneOn: microphoneOn ?? this.microphoneOn,
        cameraOn: cameraOn ?? this.cameraOn,
      );
  factory ClassroomStudent.fromJson(Map<String, dynamic> data) =>
      JsonReader(data).decode(() => ClassroomStudent._fromJsonUnchecked(data));
  factory ClassroomStudent._fromJsonUnchecked(Map<String, dynamic> data) =>
      ClassroomStudent(
        userId: JsonReader(data).required<String>('userId'),
        participantId: JsonReader(data).required<String>('participantId'),
        displayName: JsonReader(data).optional<String>('displayName') ?? '',
        online: JsonReader(data).optional<bool>('online') ?? false,
        handRaised: JsonReader(data).optional<bool>('handRaised') ?? false,
        canSpeak: JsonReader(data).optional<bool>('canSpeak') ?? false,
        role: data['role'] == null
            ? ClassroomRole.student
            : JsonReader(data).enumValue('role', ClassroomRole.values),
      );
}

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

class ClassroomState {
  ClassroomState({
    required this.roomCode,
    required this.role,
    required this.revision,
    required List<ClassroomStudent> students,
    required List<ClassroomQuestion> questions,
    required this.stats,
    this.speakEnforcement = 'advisory',
    this.selfUserId = '',
    this.tools,
    List<ClassroomAttendance> attendance = const [],
  }) : students = List.unmodifiable(students),
       questions = List.unmodifiable(questions),
       attendance = List.unmodifiable(attendance);
  final String roomCode;
  final String selfUserId;
  final ClassroomRole role;
  final int revision;
  final List<ClassroomStudent> students;
  final List<ClassroomQuestion> questions;
  final ClassroomStats stats;
  final ClassroomToolsState? tools;
  final List<ClassroomAttendance> attendance;
  // The provider's publish permission has NOT been changed by a grant.
  final String speakEnforcement;
  bool get isTeacher => role == ClassroomRole.teacher;
  ClassroomCapabilities get capabilities => ClassroomCapabilities(
    canRaiseHand: !isTeacher,
    canAskQuestion: !isTeacher,
    canManageQuestions: isTeacher,
    canGrantSpeak: isTeacher,
    canViewRoster: isTeacher,
    enforcesMicrophone: speakEnforcement == 'provider',
    canUseTools: tools != null,
    canPublishTools: isTeacher && tools != null,
  );
  List<ClassroomStudent> get raisedHands =>
      students.where((s) => s.handRaised).toList(growable: false);
  ClassroomState withMedia(
    Map<String, ({bool? microphoneOn, bool? cameraOn})> tracks,
  ) => ClassroomState(
    roomCode: roomCode,
    role: role,
    revision: revision,
    selfUserId: selfUserId,
    students: [
      for (final s in students)
        if (tracks.containsKey(s.participantId))
          s.withMedia(
            microphoneOn: tracks[s.participantId]!.microphoneOn,
            cameraOn: tracks[s.participantId]!.cameraOn,
          )
        else
          s,
    ],
    questions: questions,
    stats: stats,
    speakEnforcement: speakEnforcement,
    tools: tools,
    attendance: attendance,
  );
  ClassroomState withChatMessages(int count) => ClassroomState(
    roomCode: roomCode,
    role: role,
    revision: revision,
    selfUserId: selfUserId,
    students: students,
    questions: questions,
    stats: stats.withChatMessages(count),
    speakEnforcement: speakEnforcement,
    tools: tools,
    attendance: attendance,
  );
  factory ClassroomState.fromJson(Map<String, dynamic> data) =>
      JsonReader(data).decode(() => ClassroomState._fromJsonUnchecked(data));
  factory ClassroomState._fromJsonUnchecked(Map<String, dynamic> data) =>
      ClassroomState(
        roomCode: JsonReader(data).required<String>('roomCode'),
        selfUserId: JsonReader(data).optional<String>('selfUserId') ?? '',
        role: JsonReader(data).enumValue('role', ClassroomRole.values),
        revision: JsonReader(data).optional<int>('revision') ?? 0,
        students: List.unmodifiable(
          (data['students'] as List<dynamic>? ?? const []).map(
            (e) =>
                ClassroomStudent.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        ),
        questions: List.unmodifiable(
          (data['questions'] as List<dynamic>? ?? const []).map(
            (e) =>
                ClassroomQuestion.fromJson(Map<String, dynamic>.from(e as Map)),
          ),
        ),
        stats: ClassroomStats.fromJson(
          Map<String, dynamic>.from(data['stats'] as Map? ?? {}),
        ),
        speakEnforcement:
            JsonReader(data).optional<String>('speakEnforcement') ?? 'advisory',
        tools: data['tools'] == null
            ? null
            : ClassroomToolsState.fromJson(
                Map<String, dynamic>.from(data['tools'] as Map),
              ),
        attendance: List.unmodifiable(
          (data['attendance'] as List? ?? []).map(
            (a) => ClassroomAttendance.fromJson(
              Map<String, dynamic>.from(a as Map),
            ),
          ),
        ),
      );
}

class ClassroomNotification {
  const ClassroomNotification(this.kind, this.revision);
  final ClassroomNotificationKind kind;
  final int revision;
}
