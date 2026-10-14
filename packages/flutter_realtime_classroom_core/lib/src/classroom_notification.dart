import 'classroom_feedback.dart';
import 'classroom_notification_kind.dart';

class ClassroomNotification {
  const ClassroomNotification(
    this.kind,
    this.revision, {
    this.feedback = const [],
    this.itemId,
  });
  final ClassroomNotificationKind kind;
  final int revision;
  final List<ClassroomFeedback> feedback;

  /// Identifies the affected tool entry when multiple changes arrive in the
  /// same poll. Null for state-wide notifications and legacy event producers.
  final String? itemId;
}
