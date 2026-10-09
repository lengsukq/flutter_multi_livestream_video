import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

/// Points are relative to the shared content rectangle, excluding letterboxes.
class AnnotationPoint {
  const AnnotationPoint(this.x, this.y);
  final double x, y;
  Map<String, Object> toJson() => {'x': x, 'y': y};
  factory AnnotationPoint.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => AnnotationPoint._fromJsonUnchecked(value));
  factory AnnotationPoint._fromJsonUnchecked(Map<String, dynamic> value) =>
      AnnotationPoint(
        JsonReader(value).required<num>('x').toDouble(),
        JsonReader(value).required<num>('y').toDouble(),
      );
}

enum AnnotationTool { pen, highlight, circle, arrow, text }

class AnnotationShape {
  AnnotationShape({
    required this.id,
    required this.tool,
    required List<AnnotationPoint> points,
    this.color = 0xfff59e0b,
    this.width = 3,
    this.text = '',
  }) : points = List.unmodifiable(points);
  final String id, text;
  final AnnotationTool tool;
  final List<AnnotationPoint> points;
  final int color, width;
  Map<String, Object> toJson() => {
    'id': id,
    'tool': tool.name,
    'points': points.map((p) => p.toJson()).toList(),
    'color': color,
    'width': width,
    'text': text,
  };
  factory AnnotationShape.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => AnnotationShape._fromJsonUnchecked(value));
  factory AnnotationShape._fromJsonUnchecked(Map<String, dynamic> value) =>
      AnnotationShape(
        id: JsonReader(value).required<String>('id'),
        tool: JsonReader(value).enumValue('tool', AnnotationTool.values),
        points: JsonReader(
          value,
        ).objects('points', AnnotationPoint.fromJson, optional: false),
        color: JsonReader(value).required<int>('color'),
        width: JsonReader(value).required<int>('width'),
        text: JsonReader(value).optional<String>('text') ?? '',
      );
}

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
