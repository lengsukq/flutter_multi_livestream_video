import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Independent, non-interactive meeting overlay for trusted classroom changes.
///
/// Place it inside the host application's stage Stack. The SDK owns the event
/// interpretation; the host retains complete control of layout and placement.
/// Notifications are derived from authenticated classroom snapshots, not from
/// untrusted realtime transport messages. Initial snapshots never replay toasts.
class RealtimeClassroomEventOverlay extends StatefulWidget {
  const RealtimeClassroomEventOverlay({
    super.key,
    required this.classroom,
    this.toastDuration = const Duration(seconds: 5),
  });

  final ClassroomSession classroom;
  final Duration toastDuration;

  @override
  State<RealtimeClassroomEventOverlay> createState() =>
      _RealtimeClassroomEventOverlayState();
}

class _ClassroomToast {
  const _ClassroomToast(this.zh, this.en, this.until);
  final String zh, en;
  final DateTime until;
}

class _RealtimeClassroomEventOverlayState
    extends State<RealtimeClassroomEventOverlay> {
  StreamSubscription<ClassroomStateEvent>? _events;
  StreamSubscription<ClassroomNotification>? _notifications;
  StreamSubscription<ClassroomState>? _states;
  Timer? _clock;
  final List<_ClassroomToast> _visible = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_visible.isEmpty && widget.classroom.state?.tools?.timer == null) {
        return;
      }
      setState(
        () => _visible.removeWhere((t) => !t.until.isAfter(DateTime.now())),
      );
    });
  }

  void _subscribe() {
    _events = widget.classroom.events.listen(_onEvent);
    _notifications = widget.classroom.notifications.listen(_onNotification);
    _states = widget.classroom.states.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RealtimeClassroomEventOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classroom != widget.classroom) {
      unawaited(_events?.cancel());
      unawaited(_notifications?.cancel());
      unawaited(_states?.cancel());
      _visible.clear();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(_events?.cancel());
    unawaited(_notifications?.cancel());
    unawaited(_states?.cancel());
    super.dispose();
  }

  void _show(String zh, String en) {
    if (!mounted) return;
    setState(() {
      _visible.add(
        _ClassroomToast(zh, en, DateTime.now().add(widget.toastDuration)),
      );
      if (_visible.length > 3) _visible.removeAt(0);
    });
  }

  void _onEvent(ClassroomStateEvent event) {
    final state = widget.classroom.state;
    if (state == null) return;
    final person = state.students
        .where((s) => s.userId == event.userId)
        .firstOrNull;
    final question = state.questions
        .where((q) => q.id == event.questionId)
        .firstOrNull;
    final name = person?.displayName.isNotEmpty == true
        ? person!.displayName
        : question?.displayName.isNotEmpty == true
        ? question!.displayName
        : event.userId;
    final selfPermissionChange =
        !state.isTeacher &&
        event.userId == state.selfUserId &&
        (event.kind == ClassroomStateEventKind.speakGranted ||
            event.kind == ClassroomStateEventKind.speakRevoked);
    final (zh, en) = switch (event.kind) {
      ClassroomStateEventKind.handRaised => ('举手了', 'raised a hand'),
      ClassroomStateEventKind.handLowered => ('取消了举手', 'lowered a hand'),
      ClassroomStateEventKind.speakGranted =>
        selfPermissionChange
            ? (
                '老师已允许你发言，请打开麦克风',
                'Teacher allowed you to speak. Turn on your microphone.',
              )
            : ('获得发言权限', 'was allowed to speak'),
      ClassroomStateEventKind.speakRevoked =>
        selfPermissionChange
            ? ('老师已收回你的发言权限', 'Your speaking permission was revoked.')
            : ('发言权限已撤销', 'lost speaking permission'),
      ClassroomStateEventKind.questionAsked => ('提出了问题', 'asked a question'),
      ClassroomStateEventKind.questionAnswered => (
        '问题获得回答',
        'received an answer',
      ),
      ClassroomStateEventKind.questionResolved => (
        '问题已解决',
        'had a question resolved',
      ),
      ClassroomStateEventKind.studentJoined => (
        '加入了课堂',
        'joined the classroom',
      ),
      ClassroomStateEventKind.studentLeft => ('离开了课堂', 'left the classroom'),
      ClassroomStateEventKind.feedbackSent => (
        '发送了课堂反馈',
        'sent classroom feedback',
      ),
    };
    _show(
      selfPermissionChange ? zh : '$name $zh',
      selfPermissionChange ? en : '$name $en',
    );
  }

  void _onNotification(ClassroomNotification notice) {
    final tools = widget.classroom.state?.tools;
    // Hand, speaking and Q&A already arrive via events; do not double-toast.
    switch (notice.kind) {
      case ClassroomNotificationKind.noticePublished:
        final latest = tools?.notices.lastOrNull;
        if (latest != null) {
          _show('课堂通知：${latest.text}', 'Announcement: ${latest.text}');
        }
      case ClassroomNotificationKind.homeworkPublished:
        final latest = tools?.homework.lastOrNull;
        if (latest != null) {
          _show(
            '老师发布了作业：${latest.title}',
            'Homework published: ${latest.title}',
          );
        }
      case ClassroomNotificationKind.materialShared:
        final latest = tools?.materials.lastOrNull;
        if (latest != null) {
          _show('老师分享了资料：${latest.title}', 'Material shared: ${latest.title}');
        }
      case ClassroomNotificationKind.activityPublished:
        final latest = tools?.activities.lastOrNull;
        if (latest != null) {
          _show(
            '老师发布了互动：${latest.title}',
            'Activity published: ${latest.title}',
          );
        }
      case ClassroomNotificationKind.timerChanged:
        final timer = tools?.timer;
        _show(
          timer == null ? '课堂倒计时已停止' : '课堂倒计时已开始：${timer.title}',
          timer == null
              ? 'Classroom timer stopped'
              : 'Timer started: ${timer.title}',
        );
      case ClassroomNotificationKind.handRaised:
      case ClassroomNotificationKind.speakGranted:
      case ClassroomNotificationKind.questionAsked:
      case ClassroomNotificationKind.questionAnswered:
      case ClassroomNotificationKind.feedbackReceived:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zh = RealtimeStrings.of(context).isZh;
    final timer = widget.classroom.state?.tools?.timer;
    final remaining = timer?.remaining();
    if (timer == null && _visible.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (timer != null)
                Card(
                  key: const Key('classroom-shared-timer'),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 19),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            timer.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          remaining == Duration.zero
                              ? (zh ? '已结束' : 'Finished')
                              : '${remaining!.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final toast in _visible)
                Card(
                  key: ObjectKey(toast),
                  color: Theme.of(context).colorScheme.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      zh ? toast.zh : toast.en,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
