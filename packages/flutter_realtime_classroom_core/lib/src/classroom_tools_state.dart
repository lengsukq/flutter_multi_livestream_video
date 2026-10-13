import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'classroom_activity.dart';
import 'classroom_homework.dart';
import 'classroom_material.dart';
import 'classroom_notice.dart';
import 'classroom_timer.dart';

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
