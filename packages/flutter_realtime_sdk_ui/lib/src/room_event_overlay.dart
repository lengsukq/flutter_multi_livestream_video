import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter_realtime_shared_content_preset/flutter_realtime_shared_content_preset.dart';
import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;
import 'room_ui_controller.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Reusable room feedback for trusted classroom, media and recording events.
///
/// Place it inside the host application's stage Stack. The SDK owns the event
/// interpretation; the host retains complete control of layout and placement.
/// Notifications are derived from authenticated classroom snapshots, not from
/// untrusted realtime transport messages. Initial snapshots never replay toasts.
class RealtimeRoomEventOverlay extends StatefulWidget {
  const RealtimeRoomEventOverlay({
    super.key,
    this.classroom,
    this.room,
    this.showClassroom = true,
    this.toastDuration = const Duration(seconds: 5),
  }) : assert(room != null || classroom != null);

  final ClassroomSession? classroom;
  final RealtimeRoom? room;
  final bool showClassroom;
  final Duration toastDuration;

  @override
  State<RealtimeRoomEventOverlay> createState() =>
      _RealtimeRoomEventOverlayState();
}

class _RoomToast {
  const _RoomToast(this.id, this.zh, this.en, this.until);
  final String id, zh, en;
  final Duration until;
}

class _RealtimeRoomEventOverlayState extends State<RealtimeRoomEventOverlay> {
  StreamSubscription<ClassroomStateEvent>? _events;
  StreamSubscription<ClassroomNotification>? _notifications;
  StreamSubscription<ClassroomState>? _states;
  Timer? _clock;
  Duration _elapsed = Duration.zero;
  ClassroomSession? get _classroom =>
      widget.classroom ??
      (widget.showClassroom ? widget.room?.classroom : null);
  StreamSubscription<RealtimeEvent>? _roomEvents;
  StreamSubscription<RecordingStatus>? _recording;
  StreamSubscription<SharedContentStatus>? _shared;
  int _seenActionSequence = 0;
  RealtimeRoomUiController? _controller;
  SharedContentMode? _lastMode;
  RecordingStatus? _lastRecording;
  Object? _lastSharedError;
  MediaSessionState? _lastConnection;
  String? _persistentZh, _persistentEn;

  final List<_RoomToast> _visible = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
    _clock = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed = Duration(seconds: timer.tick);
      if (!mounted) return;
      if (_visible.isEmpty && _classroom?.state?.tools?.timer == null) {
        return;
      }
      setState(() => _visible.removeWhere((t) => t.until <= _elapsed));
    });
  }

  void _subscribe() {
    _lastMode = widget.room?.sharedContent?.content?.mode;
    _lastRecording = widget.room?.recordingStatus;
    _lastConnection = widget.room?.media.snapshot.state;
    _roomEvents = widget.room?.events.listen(_onRoomEvent);
    _recording = widget.room?.recordingStatuses.listen((status) {
      final previous = _lastRecording;
      _lastRecording = status;
      if (previous == null || previous == status) return;
      if (status == RecordingStatus.recording) {
        _show('录制已开始', 'Recording started');
      }
      if ((previous == RecordingStatus.stopping ||
              previous == RecordingStatus.recording) &&
          (status == RecordingStatus.completed ||
              status == RecordingStatus.processing ||
              status == RecordingStatus.idle)) {
        _show('录制已停止', 'Recording stopped');
      }
    });
    _shared = widget.room?.sharedContent?.statuses.listen((status) {
      final mode = status.content?.mode;
      final previous = _lastMode;
      _lastMode = mode;
      if (previous != null && mode != null && mode != previous) {
        switch (mode) {
          case SharedContentMode.members:
            _show('共享已结束', 'Sharing ended');
          case SharedContentMode.screen:
            _show('屏幕共享已开始', 'Screen sharing started');
          case SharedContentMode.whiteboard:
            _show('已打开白板', 'Whiteboard opened');
        }
      }
      final error = status.error;
      if (error != null && !identical(error, _lastSharedError)) {
        _lastSharedError = error;
        if (mounted) _controller?.reportActionError(error);
      }
    });
    _events = _classroom?.events.listen(_onEvent);
    _notifications = _classroom?.notifications.listen(_onNotification);
    _states = _classroom?.states.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RealtimeRoomEventOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classroom != widget.classroom ||
        oldWidget.room != widget.room ||
        oldWidget.showClassroom != widget.showClassroom) {
      unawaited(_events?.cancel());
      unawaited(_notifications?.cancel());
      unawaited(_states?.cancel());
      unawaited(_roomEvents?.cancel());
      unawaited(_recording?.cancel());
      unawaited(_shared?.cancel());
      _persistentZh = _persistentEn = null;
      _visible.clear();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(_roomEvents?.cancel());
    unawaited(_recording?.cancel());
    unawaited(_shared?.cancel());
    _controller?.removeListener(_onActionCompleted);
    unawaited(_events?.cancel());
    unawaited(_notifications?.cancel());
    unawaited(_states?.cancel());
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = widget.room == null
        ? null
        : RealtimeRoomUiScope.maybeOf(context);
    if (identical(controller, _controller)) return;
    _controller?.removeListener(_onActionCompleted);
    _controller = controller;
    _seenActionSequence = controller?.lastCompletedAction?.sequence ?? 0;
    controller?.addListener(_onActionCompleted);
  }

  void _onActionCompleted() {
    final controller = _controller;
    final completed = controller?.lastCompletedAction;
    if (completed == null || completed.sequence <= _seenActionSequence) return;
    _seenActionSequence = completed.sequence;
    if (completed.action == RealtimeRoomUiAction.participantManagement) {
      if (controller!.bulkMuteFailures.isEmpty) {
        _show('成员管理操作已完成', 'Participant management completed');
      } else {
        _show(
          '部分成员操作失败，请重试',
          'Some participant actions failed. Retry the failed actions.',
        );
      }
    }
  }

  void _onRoomEvent(RealtimeEvent event) {
    if (!mounted) return;
    if (event case RealtimeStateChanged(:final state)) {
      if (_lastConnection == state.media) return;
      final previous = _lastConnection;
      _lastConnection = state.media;
      if (state.media == MediaSessionState.reconnecting) {
        setState(() {
          _persistentZh = '连接中断，正在重连…';
          _persistentEn = 'Connection lost. Reconnecting…';
        });
      } else if (state.media == MediaSessionState.connected) {
        setState(() {
          _persistentZh = _persistentEn = null;
        });
        if (previous == MediaSessionState.reconnecting) {
          _show('连接已恢复', 'Connection restored');
        }
      } else if (state.media == MediaSessionState.ended ||
          state.media == MediaSessionState.failed) {
        setState(() {
          _persistentZh = '当前会话已结束';
          _persistentEn = 'This session has ended';
        });
      }
    }
    if (event case RealtimeMediaEvent(:final event)) {
      if (event is MediaParticipantJoined && _classroom == null) {
        _show(
          '${event.participant.displayName} 加入了房间',
          '${event.participant.displayName} joined',
        );
      }
      if (event is MediaParticipantLeft && _classroom == null) {
        _show(
          '${event.displayName ?? event.participantId} 离开了房间',
          '${event.displayName ?? event.participantId} left',
        );
      }
      if (widget.room?.sharedContent == null &&
          event is MediaTrackPublished &&
          event.track.isScreenShare) {
        _show('屏幕共享已开始', 'Screen sharing started');
      }
      if (widget.room?.sharedContent == null &&
          event is MediaTrackUnpublished &&
          event.wasScreenShare) {
        _show('屏幕共享已结束', 'Screen sharing ended');
      }
    }
  }

  void _show(String zh, String en, {String? dedupeKey}) {
    final id = dedupeKey ?? '$zh|$en';
    if (!mounted) return;
    setState(() {
      if (_visible.any((toast) => toast.id == id && toast.until > _elapsed)) {
        return;
      }
      _visible.add(_RoomToast(id, zh, en, _elapsed + widget.toastDuration));
      if (_visible.length > 3) _visible.removeAt(0);
    });
  }

  void _onEvent(ClassroomStateEvent event) {
    final state = _classroom?.state;
    if (state == null) return;
    final person = state.students
        .where((s) => s.userId == event.userId)
        .firstOrNull;
    final question = state.questions
        .where((q) => q.id == event.questionId)
        .firstOrNull;
    final isSelf = event.userId == state.selfUserId;
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
      selfPermissionChange ? zh : '${isSelf ? '你' : name} $zh',
      selfPermissionChange ? en : '${isSelf ? 'You' : name} $en',
      dedupeKey:
          'classroom:${event.kind}:${event.revision}:${event.userId}:${event.questionId}:${event.feedbackId}',
    );
  }

  void _onNotification(ClassroomNotification notice) {
    final tools = _classroom?.state?.tools;
    // Hand, speaking and Q&A already arrive via events; do not double-toast.
    switch (notice.kind) {
      case ClassroomNotificationKind.noticePublished:
        final latest = notice.itemId == null
            ? tools?.notices.lastOrNull
            : tools?.notices.where((n) => n.id == notice.itemId).firstOrNull;
        if (latest != null) {
          _show('课堂通知：${latest.text}', 'Announcement: ${latest.text}');
        }
      case ClassroomNotificationKind.homeworkPublished:
        final latest = notice.itemId == null
            ? tools?.homework.lastOrNull
            : tools?.homework.where((h) => h.id == notice.itemId).firstOrNull;
        if (latest != null) {
          _show(
            '老师发布了作业：${latest.title}',
            'Homework published: ${latest.title}',
          );
        }
      case ClassroomNotificationKind.materialShared:
        final latest = notice.itemId == null
            ? tools?.materials.lastOrNull
            : tools?.materials.where((m) => m.id == notice.itemId).firstOrNull;
        if (latest != null) {
          _show('老师分享了资料：${latest.title}', 'Material shared: ${latest.title}');
        }
      case ClassroomNotificationKind.activityPublished:
        final latest = notice.itemId == null
            ? tools?.activities.lastOrNull
            : tools?.activities.where((a) => a.id == notice.itemId).firstOrNull;
        if (latest != null) {
          _show(
            '老师发布了互动：${latest.title}',
            'Activity published: ${latest.title}',
          );
        }
      case ClassroomNotificationKind.activityUpdated:
        final item = tools?.activities
            .where((a) => a.id == notice.itemId)
            .firstOrNull;
        if (item != null) {
          _show(
            _classroom?.state?.isTeacher == true
                ? '${item.title}：有学生提交了回答（共 ${item.responseCount} 人）'
                : '你已提交互动回答：${item.title}',
            _classroom?.state?.isTeacher == true
                ? 'New response to ${item.title} (${item.responseCount} participants)'
                : 'Your answer was submitted: ${item.title}',
          );
        }
      case ClassroomNotificationKind.activityClosed:
        final item = tools?.activities
            .where((a) => a.id == notice.itemId)
            .firstOrNull;
        if (item != null) {
          _show('互动已结束：${item.title}', 'Activity closed: ${item.title}');
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
    final timer = _classroom?.state?.tools?.timer;
    final remaining = timer?.remaining();
    if (timer == null && _visible.isEmpty && _persistentZh == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : MediaQuery.sizeOf(context).height * .4,
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_persistentZh != null)
                    Semantics(
                      liveRegion: true,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(zh ? _persistentZh! : _persistentEn!),
                        ),
                      ),
                    ),
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
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            zh ? toast.zh : toast.en,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
