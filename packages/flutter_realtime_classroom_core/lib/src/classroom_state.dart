import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'classroom_attendance.dart';
import 'classroom_capabilities.dart';
import 'classroom_feedback.dart';
import 'classroom_note.dart';
import 'classroom_question.dart';
import 'classroom_role.dart';
import 'classroom_stats.dart';
import 'classroom_student.dart';
import 'classroom_tools_state.dart';

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
    this.feedbackSupported = true,
    List<ClassroomFeedback> feedback = const [],
    List<ClassroomAttendance> attendance = const [],
    List<ClassroomNote>? notes,
    this.notesPersistence,
  }) : students = List.unmodifiable(students),
       questions = List.unmodifiable(questions),
       attendance = List.unmodifiable(attendance),
       feedback = List.unmodifiable(feedback),
       notes = notes == null ? null : List.unmodifiable(notes);
  final String roomCode;
  final String selfUserId;
  final ClassroomRole role;
  final int revision;
  final List<ClassroomStudent> students;
  final List<ClassroomQuestion> questions;
  final ClassroomStats stats;
  final ClassroomToolsState? tools;
  final List<ClassroomAttendance> attendance;

  /// Null indicates an old backend without lesson-notes support.
  /// For security, only teacher snapshots contain this collection.
  final List<ClassroomNote>? notes;

  /// "file" persists until room closure; "session" is volatile.
  final String? notesPersistence;
  final bool feedbackSupported;

  /// Recent feedback, bounded by the repository. Students only see their own.
  final List<ClassroomFeedback> feedback;
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
    canSendFeedback: feedbackSupported && !isTeacher,
    canViewFeedback: feedbackSupported && isTeacher,
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
    notes: notes,
    notesPersistence: notesPersistence,
    feedbackSupported: feedbackSupported,
    feedback: feedback,
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
    notes: notes,
    notesPersistence: notesPersistence,
    feedbackSupported: feedbackSupported,
    feedback: feedback,
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
        notes: data['notes'] is List
            ? List.unmodifiable(
                (data['notes'] as List).map(
                  (item) => ClassroomNote.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                ),
              )
            : null,
        notesPersistence: JsonReader(data).optional<String>('notesPersistence'),
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
        feedbackSupported:
            JsonReader(data).optional<bool>('feedbackSupported') ?? true,
        feedback: [
          for (final item in data['feedback'] as List? ?? const [])
            ClassroomFeedback.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        attendance: List.unmodifiable(
          (data['attendance'] as List? ?? []).map(
            (a) => ClassroomAttendance.fromJson(
              Map<String, dynamic>.from(a as Map),
            ),
          ),
        ),
      );
}
