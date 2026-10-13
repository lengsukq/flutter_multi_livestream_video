import 'classroom_feedback.dart';
import 'classroom_notification_kind.dart';

class ClassroomNotification {
  const ClassroomNotification(
    this.kind,
    this.revision, {
    this.feedback = const [],
  });
  final ClassroomNotificationKind kind;
  final int revision;
  final List<ClassroomFeedback> feedback;
}
