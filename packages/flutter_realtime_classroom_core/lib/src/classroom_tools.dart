import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

/// Optional upload integration owned by the host application. The SDK never
/// chooses storage or uploads files to a vendor account on its own.
abstract interface class ClassroomMaterialUploader {
  Future<ClassroomMaterial> upload({
    required String filename,
    required List<int> bytes,
    required String contentType,
  });
}

class ClassroomMaterial {
  const ClassroomMaterial({
    required this.id,
    required this.title,
    required this.url,
  });
  final String id, title, url;
  factory ClassroomMaterial.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => ClassroomMaterial._fromJsonUnchecked(value));
  factory ClassroomMaterial._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomMaterial(
        id: JsonReader(value).required<String>('id'),
        title: JsonReader(value).required<String>('title'),
        url: JsonReader(value).required<String>('url'),
      );
}

class ClassroomNotice {
  const ClassroomNotice({
    required this.id,
    required this.kind,
    required this.text,
    required this.createdAt,
  });
  final String id, kind, text;
  final DateTime createdAt;
  bool get isFocusReminder => kind == 'focus';
  factory ClassroomNotice.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => ClassroomNotice._fromJsonUnchecked(value));
  factory ClassroomNotice._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomNotice(
        id: JsonReader(value).required<String>('id'),
        kind: JsonReader(value).required<String>('kind'),
        text: JsonReader(value).required<String>('text'),
        createdAt: JsonReader(value).dateTime('createdAt'),
      );
}

class ClassroomHomework {
  const ClassroomHomework({
    required this.id,
    required this.title,
    required this.instructions,
    this.dueAt,
  });
  final String id, title, instructions;
  final DateTime? dueAt;
  factory ClassroomHomework.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => ClassroomHomework._fromJsonUnchecked(value));
  factory ClassroomHomework._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomHomework(
        id: JsonReader(value).required<String>('id'),
        title: JsonReader(value).required<String>('title'),
        instructions: JsonReader(value).required<String>('instructions'),
        dueAt: value['dueAt'] == null
            ? null
            : JsonReader(value).dateTime('dueAt'),
      );
}

class ClassroomTimer {
  const ClassroomTimer({required this.title, required this.endsAt});
  final String title;
  final DateTime endsAt;
  Duration remaining({DateTime? now}) {
    final duration = endsAt.difference(now ?? DateTime.now());
    return duration.isNegative ? Duration.zero : duration;
  }

  factory ClassroomTimer.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => ClassroomTimer._fromJsonUnchecked(value));
  factory ClassroomTimer._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomTimer(
        title: JsonReader(value).required<String>('title'),
        endsAt: JsonReader(value).dateTime('endsAt'),
      );
}

enum ClassroomActivityKind { quiz, poll }

class ClassroomActivity {
  ClassroomActivity({
    required this.id,
    required this.kind,
    required this.title,
    required List<String> options,
    required this.closed,
    this.responseCount = 0,
    this.selfAnswer,
    this.correctOption,
    List<int>? counts,
    Map<String, int> answers = const {},
  }) : options = List.unmodifiable(options),
       counts = counts == null ? null : List.unmodifiable(counts),
       answers = Map.unmodifiable(answers);
  final String id, title;
  final ClassroomActivityKind kind;
  final List<String> options;
  final bool closed;
  final int responseCount;
  // Intentionally absent for students while a quiz remains open.
  final int? correctOption, selfAnswer;
  final List<int>? counts;
  final Map<String, int> answers;
  factory ClassroomActivity.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => ClassroomActivity._fromJsonUnchecked(value));
  factory ClassroomActivity._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomActivity(
        id: JsonReader(value).required<String>('id'),
        kind: JsonReader(value).enumValue('kind', ClassroomActivityKind.values),
        title: JsonReader(value).required<String>('title'),
        options: JsonReader(value).list<String>('options'),
        closed: JsonReader(value).required<bool>('closed'),
        responseCount: JsonReader(value).optional<int>('responseCount') ?? 0,
        selfAnswer: JsonReader(value).optional<int>('selfAnswer'),
        correctOption: JsonReader(value).optional<int>('correctOption'),
        counts: value['counts'] == null
            ? null
            : JsonReader(value).list<int>('counts'),
        answers: Map.unmodifiable(
          (value['answers'] as Map? ?? {}).cast<String, int>(),
        ),
      );
}

class ClassroomAttendance {
  const ClassroomAttendance({
    required this.userId,
    required this.displayName,
    required this.online,
    required this.onlineDuration,
    this.firstJoinedAt,
    this.lastJoinedAt,
    this.lastLeftAt,
  });
  final String userId, displayName;
  final bool online;
  final Duration onlineDuration;
  final DateTime? firstJoinedAt, lastJoinedAt, lastLeftAt;
  factory ClassroomAttendance.fromJson(Map<String, dynamic> value) =>
      JsonReader(
        value,
      ).decode(() => ClassroomAttendance._fromJsonUnchecked(value));
  factory ClassroomAttendance._fromJsonUnchecked(Map<String, dynamic> value) =>
      ClassroomAttendance(
        userId: JsonReader(value).required<String>('userId'),
        displayName: JsonReader(value).required<String>('displayName'),
        online: JsonReader(value).required<bool>('online'),
        onlineDuration: Duration(
          milliseconds:
              JsonReader(value).optional<int>('onlineMilliseconds') ?? 0,
        ),
        firstJoinedAt: JsonReader(value).optionalDateTime('firstJoinedAt'),
        lastJoinedAt: JsonReader(value).optionalDateTime('lastJoinedAt'),
        lastLeftAt: JsonReader(value).optionalDateTime('lastLeftAt'),
      );
}

/// Null ClassroomState.tools means the control plane has not implemented this
/// extension; a V1-only backend stays compatible and does not show dead tools.
class ClassroomToolsState {
  ClassroomToolsState({
    List<ClassroomNotice> notices = const [],
    List<ClassroomHomework> homework = const [],
    List<ClassroomMaterial> materials = const [],
    List<ClassroomActivity> activities = const [],
    this.timer,
    this.content,
    AnnotationCanvas? annotation,
  }) : annotation = annotation ?? AnnotationCanvas(),
       notices = List.unmodifiable(notices),
       homework = List.unmodifiable(homework),
       materials = List.unmodifiable(materials),
       activities = List.unmodifiable(activities);
  final List<ClassroomNotice> notices;
  final List<ClassroomHomework> homework;
  final List<ClassroomMaterial> materials;
  final List<ClassroomActivity> activities;
  final ClassroomTimer? timer;
  final AnnotationCanvas annotation;
  final SharedContentState? content;
  factory ClassroomToolsState.fromJson(Map<String, dynamic> value) =>
      JsonReader(
        value,
      ).decode(() => ClassroomToolsState._fromJsonUnchecked(value));
  factory ClassroomToolsState._fromJsonUnchecked(Map<String, dynamic> value) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) decode) =>
        List.unmodifiable(
          (value[key] as List? ?? []).map(
            (item) => decode(Map<String, dynamic>.from(item as Map)),
          ),
        );
    return ClassroomToolsState(
      notices: list('notices', ClassroomNotice.fromJson),
      homework: list('homework', ClassroomHomework.fromJson),
      materials: list('materials', ClassroomMaterial.fromJson),
      activities: list('activities', ClassroomActivity.fromJson),
      timer: value['timer'] == null
          ? null
          : ClassroomTimer.fromJson(
              Map<String, dynamic>.from(value['timer'] as Map),
            ),
      content: value['content'] == null
          ? null
          : SharedContentState.fromJson(
              Map<String, dynamic>.from(value['content'] as Map),
            ),
      annotation: AnnotationCanvas.fromJson(
        Map<String, dynamic>.from(value['annotation'] as Map? ?? {}),
      ),
    );
  }
}
