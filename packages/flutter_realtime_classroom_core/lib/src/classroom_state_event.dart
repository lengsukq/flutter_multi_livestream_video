import 'classroom_state_event_kind.dart';

/// Derived from authenticated state snapshots, never from untrusted RTC data.
class ClassroomStateEvent {
  const ClassroomStateEvent({
    required this.kind,
    required this.roomCode,
    required this.userId,
    required this.revision,
    this.questionId,
    this.feedbackId,
  });
  final ClassroomStateEventKind kind;
  final String roomCode;
  final String userId;
  final int revision;
  final String? questionId;
  final String? feedbackId;
}
