import 'classroom_command.dart';
import 'classroom.dart';
import 'annotation.dart';

/// A provider-neutral facade over the classroom's authoritative shared canvas.
class AnnotationSession implements AnnotationController {
  AnnotationSession(this.classroom);
  final ClassroomSession classroom;
  @override
  AnnotationCanvas get canvas =>
      classroom.state?.tools?.annotation ?? AnnotationCanvas();
  @override
  Stream<AnnotationCanvas> get canvases => classroom.states.map(
    (state) => state.tools?.annotation ?? AnnotationCanvas(),
  );
  @override
  bool get canEdit => classroom.state?.capabilities.canPublishTools ?? false;
  Future<void> setSource(String sourceKey) => classroom.toolAction(
    ClassroomToolAction.annotationSource,
    {'sourceKey': sourceKey},
  );
  Future<void> setEmbeddedInVideo(bool enabled) => classroom.toolAction(
    ClassroomToolAction.annotationPresentation,
    {'canvasId': canvas.canvasId, 'embeddedInVideo': enabled},
  );
  @override
  Future<void> begin(AnnotationShape shape, {required String canvasId}) =>
      classroom.toolAction(ClassroomToolAction.annotationBegin, {
        'canvasId': canvasId,
        ...shape.toJson(),
      });
  @override
  Future<void> append(
    String shapeId,
    List<AnnotationPoint> points, {
    required String canvasId,
  }) => classroom.toolAction(ClassroomToolAction.annotationAppend, {
    'canvasId': canvasId,
    'id': shapeId,
    'points': points.map((p) => p.toJson()).toList(),
  });
  @override
  Future<void> erase(String shapeId, {required String canvasId}) =>
      classroom.toolAction(ClassroomToolAction.annotationErase, {
        'canvasId': canvasId,
        'id': shapeId,
      });
  @override
  Future<void> undo() => classroom.toolAction(
    ClassroomToolAction.annotationUndo,
    {'canvasId': canvas.canvasId},
  );
  @override
  Future<void> clear() => classroom.toolAction(
    ClassroomToolAction.annotationClear,
    {'canvasId': canvas.canvasId},
  );
}
