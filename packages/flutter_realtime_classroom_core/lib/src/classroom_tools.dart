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
  factory ClassroomMaterial.fromJson(Map<String, dynamic> value) =>
      ClassroomMaterial(
        id: value['id'] as String,
        title: value['title'] as String,
        url: value['url'] as String,
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
      ClassroomNotice(
        id: value['id'] as String,
        kind: value['kind'] as String,
        text: value['text'] as String,
        createdAt: DateTime.parse(value['createdAt'] as String),
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
  factory ClassroomHomework.fromJson(Map<String, dynamic> value) =>
      ClassroomHomework(
        id: value['id'] as String,
        title: value['title'] as String,
        instructions: value['instructions'] as String,
        dueAt: value['dueAt'] == null
            ? null
            : DateTime.parse(value['dueAt'] as String),
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

  factory ClassroomTimer.fromJson(Map<String, dynamic> value) => ClassroomTimer(
    title: value['title'] as String,
    endsAt: DateTime.parse(value['endsAt'] as String),
  );
}

enum ClassroomActivityKind { quiz, poll }

class ClassroomActivity {
  const ClassroomActivity({
    required this.id,
    required this.kind,
    required this.title,
    required this.options,
    required this.closed,
    this.responseCount = 0,
    this.selfAnswer,
    this.correctOption,
    this.counts,
    this.answers = const {},
  });
  final String id, title;
  final ClassroomActivityKind kind;
  final List<String> options;
  final bool closed;
  final int responseCount;
  // Intentionally absent for students while a quiz remains open.
  final int? correctOption, selfAnswer;
  final List<int>? counts;
  final Map<String, int> answers;
  factory ClassroomActivity.fromJson(Map<String, dynamic> value) =>
      ClassroomActivity(
        id: value['id'] as String,
        kind: ClassroomActivityKind.values.byName(value['kind'] as String),
        title: value['title'] as String,
        options: List.unmodifiable((value['options'] as List).cast<String>()),
        closed: value['closed'] as bool,
        responseCount: value['responseCount'] as int? ?? 0,
        selfAnswer: value['selfAnswer'] as int?,
        correctOption: value['correctOption'] as int?,
        counts: value['counts'] == null
            ? null
            : List.unmodifiable((value['counts'] as List).cast<int>()),
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
      ClassroomAttendance(
        userId: value['userId'] as String,
        displayName: value['displayName'] as String,
        online: value['online'] as bool,
        onlineDuration: Duration(
          milliseconds: value['onlineMilliseconds'] as int? ?? 0,
        ),
        firstJoinedAt: DateTime.tryParse(
          value['firstJoinedAt'] as String? ?? '',
        ),
        lastJoinedAt: DateTime.tryParse(value['lastJoinedAt'] as String? ?? ''),
        lastLeftAt: DateTime.tryParse(value['lastLeftAt'] as String? ?? ''),
      );
}

/// Null ClassroomState.tools means the control plane has not implemented this
/// extension; a V1-only backend stays compatible and does not show dead tools.
class ClassroomToolsState {
  const ClassroomToolsState({
    this.notices = const [],
    this.homework = const [],
    this.materials = const [],
    this.activities = const [],
    this.timer,
    this.content,
    this.annotation = const AnnotationCanvas(),
  });
  final List<ClassroomNotice> notices;
  final List<ClassroomHomework> homework;
  final List<ClassroomMaterial> materials;
  final List<ClassroomActivity> activities;
  final ClassroomTimer? timer;
  final AnnotationCanvas annotation;
  final SharedContentState? content;
  factory ClassroomToolsState.fromJson(Map<String, dynamic> value) {
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
