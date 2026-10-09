import 'classroom_models.dart';

void deriveClassroomChanges(
  ClassroomState? old,
  ClassroomState next,
  void Function(ClassroomStateEvent) onEvent,
  void Function(ClassroomNotification) onNotification,
) {
  if (old?.tools != null && next.tools != null) {
    void added<T>(
      List<T> prior,
      List<T> current,
      String Function(T) id,
      ClassroomNotificationKind kind,
    ) {
      final ids = prior.map(id).toSet();
      if (current.any((item) => !ids.contains(id(item)))) {
        onNotification(ClassroomNotification(kind, next.revision));
      }
    }

    added(
      old!.tools!.notices,
      next.tools!.notices,
      (n) => n.id,
      ClassroomNotificationKind.noticePublished,
    );
    added(
      old.tools!.activities,
      next.tools!.activities,
      (a) => a.id,
      ClassroomNotificationKind.activityPublished,
    );
    added(
      old.tools!.homework,
      next.tools!.homework,
      (a) => a.id,
      ClassroomNotificationKind.homeworkPublished,
    );
    added(
      old.tools!.materials,
      next.tools!.materials,
      (a) => a.id,
      ClassroomNotificationKind.materialShared,
    );
    if (old.tools!.timer?.endsAt != next.tools!.timer?.endsAt) {
      onNotification(
        ClassroomNotification(
          ClassroomNotificationKind.timerChanged,
          next.revision,
        ),
      );
    }
  }
  if (old != null && next.revision > old.revision) {
    final priorFeedbackIds = old.feedback.map((item) => item.id).toSet();
    final addedFeedback = next.feedback
        .where((item) => !priorFeedbackIds.contains(item.id))
        .toList(growable: false);
    for (final item in addedFeedback) {
      onEvent(
        ClassroomStateEvent(
          kind: ClassroomStateEventKind.feedbackSent,
          roomCode: next.roomCode,
          userId: item.userId,
          revision: next.revision,
          feedbackId: item.id,
        ),
      );
    }
    if (next.isTeacher && addedFeedback.isNotEmpty) {
      onNotification(
        ClassroomNotification(
          ClassroomNotificationKind.feedbackReceived,
          next.revision,
          feedback: List.unmodifiable(addedFeedback),
        ),
      );
    }
    void emit(
      ClassroomStateEventKind kind,
      String userId, [
      String? questionId,
    ]) {
      onEvent(
        ClassroomStateEvent(
          kind: kind,
          roomCode: next.roomCode,
          userId: userId,
          revision: next.revision,
          questionId: questionId,
        ),
      );
    }

    final oldRoster = {for (final s in old.students) s.userId: s};
    for (final student in next.students) {
      final prior = oldRoster[student.userId];
      if (prior == null || prior.online != student.online) {
        emit(
          student.online
              ? ClassroomStateEventKind.studentJoined
              : ClassroomStateEventKind.studentLeft,
          student.userId,
        );
      }
      if (prior == null || prior.handRaised != student.handRaised) {
        if (student.handRaised) {
          emit(ClassroomStateEventKind.handRaised, student.userId);
        } else if (prior?.handRaised == true) {
          emit(ClassroomStateEventKind.handLowered, student.userId);
        }
      }
      if (prior != null && prior.canSpeak != student.canSpeak) {
        emit(
          student.canSpeak
              ? ClassroomStateEventKind.speakGranted
              : ClassroomStateEventKind.speakRevoked,
          student.userId,
        );
      }
    }
    final previousQuestions = {for (final q in old.questions) q.id: q};
    for (final question in next.questions) {
      final prior = previousQuestions[question.id];
      if (prior == null) {
        emit(
          ClassroomStateEventKind.questionAsked,
          question.userId,
          question.id,
        );
      } else if (prior.status != question.status) {
        emit(
          question.status == ClassroomQuestionStatus.resolved
              ? ClassroomStateEventKind.questionResolved
              : ClassroomStateEventKind.questionAnswered,
          question.userId,
          question.id,
        );
      }
    }
    final oldHands = old.raisedHands.map((s) => s.userId).toSet();
    final newHands = next.raisedHands.map((s) => s.userId).toSet();
    if (!next.isTeacher &&
        next.students.any(
          (student) =>
              student.userId == next.selfUserId &&
              student.canSpeak &&
              oldRoster[student.userId]?.canSpeak == false,
        )) {
      onNotification(
        ClassroomNotification(
          ClassroomNotificationKind.speakGranted,
          next.revision,
        ),
      );
    }
    if (next.isTeacher && newHands.difference(oldHands).isNotEmpty) {
      onNotification(
        ClassroomNotification(
          ClassroomNotificationKind.handRaised,
          next.revision,
        ),
      );
    }
    final oldQuestionIds = old.questions.map((q) => q.id).toSet();
    if (next.isTeacher &&
        next.questions.any((q) => !oldQuestionIds.contains(q.id))) {
      onNotification(
        ClassroomNotification(
          ClassroomNotificationKind.questionAsked,
          next.revision,
        ),
      );
    }
    if (next.questions.any(
      (q) =>
          q.userId == next.selfUserId &&
          q.status == ClassroomQuestionStatus.answered &&
          old.questions.any(
            (p) => p.id == q.id && p.status == ClassroomQuestionStatus.pending,
          ),
    )) {
      onNotification(
        ClassroomNotification(
          ClassroomNotificationKind.questionAnswered,
          next.revision,
        ),
      );
    }
  }
}
