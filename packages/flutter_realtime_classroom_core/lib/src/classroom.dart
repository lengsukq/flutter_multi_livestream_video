import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'classroom_tools.dart';
import 'annotation.dart';
import 'package:http/http.dart' as http;

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
      ClassroomQuestion(
        id: data['id'] as String,
        userId: data['userId'] as String,
        displayName: data['displayName'] as String? ?? '',
        text: data['text'] as String,
        status: ClassroomQuestionStatus.values.byName(data['status'] as String),
        createdAt: DateTime.parse(data['createdAt'] as String),
        answer: data['answer'] as String?,
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
      ClassroomStudent(
        userId: data['userId'] as String,
        participantId: data['participantId'] as String,
        displayName: data['displayName'] as String? ?? '',
        online: data['online'] as bool? ?? false,
        handRaised: data['handRaised'] as bool? ?? false,
        canSpeak: data['canSpeak'] as bool? ?? false,
        role: ClassroomRole.values.byName(data['role'] as String? ?? 'student'),
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
  factory ClassroomStats.fromJson(Map<String, dynamic> data) => ClassroomStats(
    onlineCount: data['onlineCount'] as int? ?? 0,
    onlineStudents: data['onlineStudents'] as int? ?? 0,
    studentsTotal: data['studentsTotal'] as int? ?? 0,
    handsRaised: data['handsRaised'] as int? ?? 0,
    pendingQuestions: data['pendingQuestions'] as int? ?? 0,
    questionsTotal: data['questionsTotal'] as int? ?? 0,
    speakGrants: data['speakGrants'] as int? ?? 0,
    chatMessages: data['chatMessages'] as int? ?? 0,
    handRaisesTotal: data['handRaisesTotal'] as int? ?? 0,
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
  const ClassroomState({
    required this.roomCode,
    required this.role,
    required this.revision,
    required this.students,
    required this.questions,
    required this.stats,
    this.speakEnforcement = 'advisory',
    this.selfUserId = '',
    this.tools,
    this.attendance = const [],
  });
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
  factory ClassroomState.fromJson(Map<String, dynamic> data) => ClassroomState(
    roomCode: data['roomCode'] as String,
    selfUserId: data['selfUserId'] as String? ?? '',
    role: ClassroomRole.values.byName(data['role'] as String),
    revision: data['revision'] as int? ?? 0,
    students: List.unmodifiable(
      (data['students'] as List<dynamic>? ?? const []).map(
        (e) => ClassroomStudent.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    ),
    questions: List.unmodifiable(
      (data['questions'] as List<dynamic>? ?? const []).map(
        (e) => ClassroomQuestion.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    ),
    stats: ClassroomStats.fromJson(
      Map<String, dynamic>.from(data['stats'] as Map? ?? {}),
    ),
    speakEnforcement: data['speakEnforcement'] as String? ?? 'advisory',
    tools: data['tools'] == null
        ? null
        : ClassroomToolsState.fromJson(
            Map<String, dynamic>.from(data['tools'] as Map),
          ),
    attendance: List.unmodifiable(
      (data['attendance'] as List? ?? []).map(
        (a) =>
            ClassroomAttendance.fromJson(Map<String, dynamic>.from(a as Map)),
      ),
    ),
  );
}

class ClassroomNotification {
  const ClassroomNotification(this.kind, this.revision);
  final ClassroomNotificationKind kind;
  final int revision;
}

abstract interface class ClassroomRepository {
  Future<ClassroomState> snapshot();
  Future<ClassroomState> action(
    String type, {
    Map<String, String> data = const {},
  });
  void close();
}

/// This is a control-plane fallback: no websocket infrastructure is required.
/// A future IM/RTC event adapter can call refresh() to deliver updates sooner.
class HttpClassroomRepository implements ClassroomRepository {
  HttpClassroomRepository({
    required String backendUrl,
    required this.roomCode,
    required this.participantId,
    required this.participantCredential,
    this.roomOwnerCredential,
    this.tokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(backendUrl),
       _client = client ?? http.Client(),
       _ownsClient = client == null;
  final Uri _baseUri;
  final String roomCode, participantId, participantCredential;
  final String? roomOwnerCredential;
  final FutureOr<String?> Function()? tokenProvider;
  final http.Client _client;
  final bool _ownsClient;
  static final Random _secure = Random.secure();
  Uri _route(String operation) => _baseUri.replace(
    path:
        '${_baseUri.path.replaceFirst(RegExp(r'/$'), '')}/rooms/${Uri.encodeComponent(roomCode)}/classroom/$operation',
  );
  Future<ClassroomState> _post(
    String operation,
    Map<String, Object?> data,
  ) async {
    final bearer = await tokenProvider?.call();
    final response = await _client
        .post(
          _route(operation),
          headers: {
            'Content-Type': 'application/json',
            if (bearer != null && bearer.isNotEmpty)
              'Authorization': 'Bearer $bearer',
          },
          body: jsonEncode({
            'requesterParticipantId': participantId,
            'participantCredential': participantCredential,
            if (roomOwnerCredential != null)
              'roomOwnerCredential': roomOwnerCredential,
            ...data,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError(
        'Classroom $operation failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }
    return ClassroomState.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body) as Map),
    );
  }

  @override
  Future<ClassroomState> snapshot() => _post('snapshot', const {});
  @override
  Future<ClassroomState> action(
    String type, {
    Map<String, String> data = const {},
  }) => _post('action', {
    'action': type,
    // A unique id is generated once per logical action, allowing the same
    // HTTP request body to be retried without applying the action twice.
    'eventId':
        '${DateTime.now().microsecondsSinceEpoch}-${_secure.nextInt(1 << 32)}',
    ...data,
  });
  @override
  void close() {
    if (_ownsClient) _client.close();
  }
}

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
  ClassroomState? get state => _state;
  Stream<ClassroomState> get states => _states.stream;
  Stream<ClassroomNotification> get notifications => _notifications.stream;
  Stream<ClassroomStateEvent> get events => _events.stream;
  Stream<Object> get errors => _errors.stream;

  Future<void> start() async {
    if (_disposed) throw StateError('Classroom disposed');
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
    if (_disposed) return Future.error(StateError('Classroom disposed'));
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
    _setState(await repository.snapshot());
  }

  void _setState(ClassroomState next) {
    if (_disposed) return;
    if (mediaTracks != null) next = next.withMedia(mediaTracks!());
    if (chatMessages != null) next = next.withChatMessages(chatMessages!());
    final old = _state;
    if (old != null && next.revision < old.revision) return;
    _state = next;
    if (old?.tools != null && next.tools != null) {
      void added<T>(
        List<T> prior,
        List<T> current,
        String Function(T) id,
        ClassroomNotificationKind kind,
      ) {
        final ids = prior.map(id).toSet();
        if (current.any((item) => !ids.contains(id(item)))) {
          _notifications.add(ClassroomNotification(kind, next.revision));
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
        _notifications.add(
          ClassroomNotification(
            ClassroomNotificationKind.timerChanged,
            next.revision,
          ),
        );
      }
    }
    if (old != null && next.revision > old.revision) {
      void emit(
        ClassroomStateEventKind kind,
        String userId, [
        String? questionId,
      ]) {
        _events.add(
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
        _notifications.add(
          ClassroomNotification(
            ClassroomNotificationKind.speakGranted,
            next.revision,
          ),
        );
      }
      if (next.isTeacher && newHands.difference(oldHands).isNotEmpty) {
        _notifications.add(
          ClassroomNotification(
            ClassroomNotificationKind.handRaised,
            next.revision,
          ),
        );
      }
      final oldQuestionIds = old.questions.map((q) => q.id).toSet();
      if (next.isTeacher &&
          next.questions.any((q) => !oldQuestionIds.contains(q.id))) {
        _notifications.add(
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
              (p) =>
                  p.id == q.id && p.status == ClassroomQuestionStatus.pending,
            ),
      )) {
        _notifications.add(
          ClassroomNotification(
            ClassroomNotificationKind.questionAnswered,
            next.revision,
          ),
        );
      }
    }
    _states.add(next);
  }

  Future<void> _act(String type, [Map<String, String> data = const {}]) async {
    if (_disposed) throw StateError('Classroom disposed');
    _setState(await repository.action(type, data: data));
    final transport = revisionTransport;
    if (!_disposed && transport != null && _state != null) {
      try {
        await transport.publish(_state!.revision);
      } catch (error) {
        if (!_disposed) _errors.add(error);
      }
    }
  }

  Future<void> raiseHand() => _act('hand.raise');
  Future<void> lowerHand() => _act('hand.lower');
  Future<void> grantSpeak(String userId) =>
      _act('speak.grant', {'userId': userId});
  Future<void> revokeSpeak(String userId) =>
      _act('speak.revoke', {'userId': userId});
  Future<void> askQuestion(String question) =>
      _act('question.ask', {'text': question});
  Future<void> answerQuestion(String id, String answer) =>
      _act('question.answer', {'questionId': id, 'text': answer});
  Future<void> resolveQuestion(String id) =>
      _act('question.resolve', {'questionId': id});

  /// Structured extensions use the existing string action contract so custom
  /// V1 repositories do not need a source-breaking signature migration.
  Future<void> toolAction(
    String action,
    Map<String, Object?> data, {
    String? eventId,
  }) async {
    if (_state == null) await start();
    if (_state?.tools == null) {
      throw UnsupportedError(
        'Classroom tools are not supported by this repository',
      );
    }
    await _act('tool.$action', {
      'payload': jsonEncode(data),
      if (eventId != null) 'eventId': eventId,
    });
  }

  Future<void> publishAnnouncement(String text) =>
      toolAction('notice.publish', {'kind': 'announcement', 'text': text});
  Future<void> remindFocus(String text) =>
      toolAction('notice.publish', {'kind': 'focus', 'text': text});
  Future<void> publishHomework({
    required String title,
    required String instructions,
    DateTime? dueAt,
  }) => toolAction('homework.publish', {
    'title': title,
    'instructions': instructions,
    if (dueAt != null) 'dueAt': dueAt.toUtc().toIso8601String(),
  });
  Future<void> shareMaterial({required String title, required String url}) =>
      toolAction('material.share', {'title': title, 'url': url});
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
  }) => toolAction('timer.start', {
    'title': title,
    'seconds': duration.inSeconds,
  });
  Future<void> stopTimer() => toolAction('timer.stop', {});
  Future<void> publishActivity({
    required ClassroomActivityKind kind,
    required String title,
    required List<String> options,
    int? correctOption,
  }) => toolAction('activity.publish', {
    'kind': kind.name,
    'title': title,
    'options': options,
    if (correctOption != null) 'correctOption': correctOption,
  });
  Future<void> answerActivity(String activityId, int option) => toolAction(
    'activity.answer',
    {'activityId': activityId, 'option': option},
  );
  Future<void> closeActivity(String activityId) =>
      toolAction('activity.close', {'activityId': activityId});
  late final AnnotationSession annotations = AnnotationSession(this);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _automaticRefreshTimer?.cancel();
    _automaticRefreshRequested = false;
    try {
      await _pending;
    } catch (_) {
      // The original refresh caller already receives this error.
    }
    await _revisionSubscription?.cancel();
    await revisionTransport?.dispose();
    repository.close();
    await _states.close();
    await _events.close();
    await _notifications.close();
    await _errors.close();
  }
}

/// A provider-neutral facade over the classroom's authoritative shared canvas.
class AnnotationSession implements AnnotationController {
  AnnotationSession(this.classroom);
  final ClassroomSession classroom;
  @override
  AnnotationCanvas get canvas =>
      classroom.state?.tools?.annotation ?? const AnnotationCanvas();
  @override
  Stream<AnnotationCanvas> get canvases => classroom.states.map(
    (state) => state.tools?.annotation ?? const AnnotationCanvas(),
  );
  @override
  bool get canEdit => classroom.state?.capabilities.canPublishTools ?? false;
  Future<void> setSource(String sourceKey) =>
      classroom.toolAction('annotation.source', {'sourceKey': sourceKey});
  Future<void> setEmbeddedInVideo(bool enabled) => classroom.toolAction(
    'annotation.presentation',
    {'canvasId': canvas.canvasId, 'embeddedInVideo': enabled},
  );
  @override
  Future<void> begin(AnnotationShape shape, {required String canvasId}) =>
      classroom.toolAction('annotation.begin', {
        'canvasId': canvasId,
        ...shape.toJson(),
      });
  @override
  Future<void> append(
    String shapeId,
    List<AnnotationPoint> points, {
    required String canvasId,
  }) => classroom.toolAction('annotation.append', {
    'canvasId': canvasId,
    'id': shapeId,
    'points': points.map((p) => p.toJson()).toList(),
  });
  @override
  Future<void> undo() =>
      classroom.toolAction('annotation.undo', {'canvasId': canvas.canvasId});
  @override
  Future<void> clear() =>
      classroom.toolAction('annotation.clear', {'canvasId': canvas.canvasId});
}
