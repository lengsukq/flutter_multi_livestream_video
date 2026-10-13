import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'annotation_shape.dart';

class AnnotationCanvas {
  AnnotationCanvas({
    this.canvasId = '',
    this.sourceKey = '',
    this.participantId = '',
    List<AnnotationShape> shapes = const [],
    this.embeddedInVideo = false,
  }) : shapes = List.unmodifiable(shapes);
  final String canvasId, sourceKey, participantId;
  final List<AnnotationShape> shapes;

  /// True when the teacher's system drawing window is captured in the video.
  /// Receivers must not draw the same vector marks a second time.
  final bool embeddedInVideo;
  bool get active => sourceKey.isNotEmpty;
  factory AnnotationCanvas.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => AnnotationCanvas._fromJsonUnchecked(value));
  factory AnnotationCanvas._fromJsonUnchecked(Map<String, dynamic> value) =>
      AnnotationCanvas(
        canvasId: JsonReader(value).optional<String>('canvasId') ?? '',
        sourceKey: JsonReader(value).optional<String>('sourceKey') ?? '',
        participantId:
            JsonReader(value).optional<String>('participantId') ?? '',
        embeddedInVideo:
            (JsonReader(value).optional<bool>('embeddedInVideo') ?? false),
        shapes: JsonReader(
          value,
        ).objects('shapes', AnnotationShape.fromJson, optional: true),
      );
}
