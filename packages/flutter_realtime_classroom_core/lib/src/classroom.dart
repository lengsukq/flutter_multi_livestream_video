import 'classroom_activity_kind.dart';
import 'classroom_feedback_kind.dart';
import 'classroom_material_uploader.dart';
import 'classroom_notification.dart';
import 'classroom_revision_transport.dart';
import 'classroom_state.dart';
import 'classroom_state_event.dart';
import 'dart:async';
import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'classroom_repository.dart';
import 'classroom_command.dart';
import 'classroom_annotations.dart';
import 'classroom_changes.dart';

/// SDK-owned state and API, independent of the Demo UI.
class ClassroomSession {
  ClassroomSession(
    this.repository, {
    this.pollInterval = const Duration(seconds: 2),
    this.mediaTracks,
    this.chatMessages,
    this.revisionTransport,
  });
  final ClassroomRepository repository;
  final Duration pollInterval;
  final Map<String, ({bool? microphoneOn, bool? cameraOn})> Function()?
  mediaTracks;
  final int Function()? chatMessages;
  final ClassroomRevisionTransport? revisionTransport;
  StreamSubscription<int>? _revisionSubscription;
  final _states = StreamController<ClassroomState>.broadcast();
  final _notifications = StreamController<ClassroomNotification>.broadcast();
  final _events = StreamController<ClassroomStateEvent>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  Timer? _timer;
  Future<void>? _pending;
  ClassroomState? _state;
  Timer? _automaticRefreshTimer;
  bool _automaticRefreshRequested = false;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);
  ClassroomState? get state => _state;
  Stream<ClassroomState> get states => _states.stream;
  Stream<ClassroomNotification> get notifications => _notifications.stream;
  Stream<ClassroomStateEvent> get events => _events.stream;
  Stream<Object> get errors => _errors.stream;

  Future<void> start() async {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Classroom disposed',
      );
    }
    _revisionSubscription ??= revisionTransport?.revisions.listen(
      (revision) {
        if (revision > (_state?.revision ?? -1)) _requestAutomaticRefresh();
      },
      onError: (Object error) {
        if (!_disposed) _errors.add(error);
      },
    );
    _timer ??= Timer.periodic(pollInterval, (_) => _requestAutomaticRefresh());
    await refresh();
  }

  void _requestAutomaticRefresh() {
    if (_disposed) return;
    _automaticRefreshRequested = true;
    _drainAutomaticRefresh();
  }

  void _drainAutomaticRefresh() {
    if (_disposed ||
        !_automaticRefreshRequested ||
        _pending != null ||
        _automaticRefreshTimer != null) {
      return;
    }
    unawaited(
      refresh().catchError((Object error) {
        if (!_disposed) _errors.add(error);
      }),
    );
  }

  /// Explicit reads bypass the automatic cooldown; all reads share one flight.
  Future<void> refresh() {
    if (_disposed) {
      return Future.error(
        const RealtimeException(
          code: RealtimeErrorCode.invalidState,
          message: 'Classroom disposed',
        ),
      );
    }
    if (_pending != null) return _pending!;
    _automaticRefreshRequested = false;
    _automaticRefreshTimer?.cancel();
    _automaticRefreshTimer = Timer(const Duration(seconds: 1), () {
      _automaticRefreshTimer = null;
      _drainAutomaticRefresh();
    });
    return _pending = _reload().whenComplete(() {
      _pending = null;
      _drainAutomaticRefresh();
    });
  }

  Future<void> _reload() async {
    try {
      _setState(await repository.snapshot());
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'classroom',
          operation: 'snapshot',
          stackTrace: stack,
        ),
        stack,
      );
    }
  }

  void _setState(ClassroomState next) {
    if (_disposed) return;
    if (mediaTracks != null) next = next.withMedia(mediaTracks!());
    if (chatMessages != null) next = next.withChatMessages(chatMessages!());
    final old = _state;
    if (old != null && next.revision < old.revision) return;
    _state = next;
    deriveClassroomChanges(old, next, _events.add, _notifications.add);
    _states.add(next);
  }

  Future<void> _act(ClassroomCommand command) async {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'Classroom disposed',
      );
    }
    try {
      _setState(await repository.action(command));
    } catch (error, stack) {
      Error.throwWithStackTrace(
        normalizeRealtimeException(
          error,
          domain: 'classroom',
          operation: command.wireName,
          stackTrace: stack,
        ),
        stack,
      );
    }
    final transport = revisionTransport;
    if (!_disposed && transport != null && _state != null) {
      try {
        await transport.publish(_state!.revision);
      } catch (error) {
        if (!_disposed) _errors.add(error);
      }
    }
  }

  Future<void> execute(ClassroomCommand command) => _act(command);

  Future<void> raiseHand() => _act(ClassroomCommand(ClassroomAction.handRaise));
  Future<void> lowerHand() => _act(ClassroomCommand(ClassroomAction.handLower));
  Future<void> sendFeedback(ClassroomFeedbackKind kind) async {
    if (_state == null) await start();
    if (_state?.feedbackSupported != true) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Classroom feedback is not supported by this repository.',
      );
    }
    if (_state!.isTeacher) {
      throw const RealtimeException(
        code: RealtimeErrorCode.forbidden,
        message: 'Only students can send classroom feedback.',
      );
    }
    await _act(
      ClassroomCommand(ClassroomAction.feedbackSend, {'kind': kind.name}),
    );
  }

  Future<void> grantSpeak(String userId) =>
      _act(ClassroomCommand(ClassroomAction.speakGrant, {'userId': userId}));
  Future<void> revokeSpeak(String userId) =>
      _act(ClassroomCommand(ClassroomAction.speakRevoke, {'userId': userId}));
  Future<void> askQuestion(String question) =>
      _act(ClassroomCommand(ClassroomAction.questionAsk, {'text': question}));
  Future<void> answerQuestion(String id, String answer) => _act(
    ClassroomCommand(ClassroomAction.questionAnswer, {
      'questionId': id,
      'text': answer,
    }),
  );
  Future<void> resolveQuestion(String id) => _act(
    ClassroomCommand(ClassroomAction.questionResolve, {'questionId': id}),
  );

  /// Teacher-only notes. The repository enforces ownership and persists
  /// changes where configured; no local optimistic notes are fabricated.
  Future<void> _noteAction(ClassroomCommand command) async {
    if (_state == null) await start();
    if (_state?.isTeacher != true) {
      throw const RealtimeException(
        code: RealtimeErrorCode.forbidden,
        message: 'Only teachers may edit classroom notes.',
      );
    }
    if (_state?.notes == null) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Classroom notes are not supported by this repository.',
      );
    }
    await _act(command);
  }

  Future<void> addNote(String text, {bool chapter = false}) => _noteAction(
    ClassroomCommand(ClassroomAction.noteAdd, {
      'text': text,
      'kind': chapter ? 'chapter' : 'note',
    }),
  );

  Future<void> updateNote(String id, String text) => _noteAction(
    ClassroomCommand(ClassroomAction.noteUpdate, {'noteId': id, 'text': text}),
  );

  Future<void> deleteNote(String id) =>
      _noteAction(ClassroomCommand(ClassroomAction.noteDelete, {'noteId': id}));

  /// Typed tool commands preserve the backend wire contract at the repository boundary.
  Future<void> toolAction(
    ClassroomToolAction action,
    Map<String, Object?> data, {
    String? eventId,
  }) async {
    if (_state == null) await start();
    if (_state?.tools == null) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'Classroom tools are not supported by this repository',
      );
    }
    await _act(ClassroomCommand.tool(action, data, eventId: eventId));
  }

  Future<void> publishAnnouncement(String text) => toolAction(
    ClassroomToolAction.noticePublish,
    {'kind': 'announcement', 'text': text},
  );
  Future<void> remindFocus(String text) => toolAction(
    ClassroomToolAction.noticePublish,
    {'kind': 'focus', 'text': text},
  );
  Future<void> publishHomework({
    required String title,
    required String instructions,
    DateTime? dueAt,
  }) => toolAction(ClassroomToolAction.homeworkPublish, {
    'title': title,
    'instructions': instructions,
    if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
  });
  Future<void> shareMaterial({required String title, required String url}) =>
      toolAction(ClassroomToolAction.materialShare, {
        'title': title,
        'url': url,
      });
  Future<void> uploadMaterial({
    required ClassroomMaterialUploader uploader,
    required String filename,
    required List<int> bytes,
    required String contentType,
  }) async {
    final material = await uploader.upload(
      filename: filename,
      bytes: bytes,
      contentType: contentType,
    );
    await shareMaterial(title: material.title, url: material.url);
  }

  Future<void> startTimer({
    required String title,
    required Duration duration,
  }) => toolAction(ClassroomToolAction.timerStart, {
    'title': title,
    'seconds': duration.inSeconds,
  });
  Future<void> stopTimer() => toolAction(ClassroomToolAction.timerStop, {});
  Future<void> publishActivity({
    required ClassroomActivityKind kind,
    required String title,
    required List<String> options,
    int? correctOption,
  }) => toolAction(ClassroomToolAction.activityPublish, {
    'kind': kind.name,
    'title': title,
    'options': options,
    if (correctOption != null) 'correctOption': correctOption,
  });
  Future<void> answerActivity(String activityId, int option) => toolAction(
    ClassroomToolAction.activityAnswer,
    {'activityId': activityId, 'option': option},
  );
  Future<void> closeActivity(String activityId) =>
      toolAction(ClassroomToolAction.activityClose, {'activityId': activityId});
  late final AnnotationSession annotations = AnnotationSession(this);

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('poll.timer', () async {
      _timer?.cancel();
    });
    await cleanup.run('refresh.timer', () async {
      _automaticRefreshTimer?.cancel();
      _automaticRefreshRequested = false;
    });
    await cleanup.run('refresh.pending', () async {
      try {
        await _pending;
      } catch (_) {
        /* The refresh caller receives its failure. */
      }
    });
    await cleanup.run('revision.subscription', () async {
      await _revisionSubscription?.cancel();
    });
    await cleanup.run('revision.transport', () async {
      await revisionTransport?.dispose();
    });
    await cleanup.run('repository', () async {
      repository.close();
    });
    await cleanup.run('states', () async {
      await _states.close();
    });
    await cleanup.run('events', () async {
      await _events.close();
    });
    await cleanup.run('notifications', () async {
      await _notifications.close();
    });
    await cleanup.run('errors', () async {
      await _errors.close();
    });
    cleanup.finish(domain: 'classroom');
  }
}
