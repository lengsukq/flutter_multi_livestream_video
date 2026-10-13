import 'annotation_canvas.dart';
import 'annotation_point.dart';
import 'annotation_shape.dart';

/// Shared drawing surface contract, with no dependency on rooms or media.
abstract interface class AnnotationController {
  AnnotationCanvas get canvas;
  Stream<AnnotationCanvas> get canvases;
  bool get canEdit;
  Future<void> begin(AnnotationShape shape, {required String canvasId});
  Future<void> append(
    String shapeId,
    List<AnnotationPoint> points, {
    required String canvasId,
  });
  Future<void> undo();
  Future<void> clear();
}
