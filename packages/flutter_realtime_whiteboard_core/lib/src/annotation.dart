/// Points are relative to the shared content rectangle, excluding letterboxes.
class AnnotationPoint {
  const AnnotationPoint(this.x, this.y);
  final double x, y;
  Map<String, Object> toJson() => {'x': x, 'y': y};
  factory AnnotationPoint.fromJson(Map<String, dynamic> value) =>
      AnnotationPoint(
        (value['x'] as num).toDouble(),
        (value['y'] as num).toDouble(),
      );
}

enum AnnotationTool { pen, highlight, circle, arrow, text }

class AnnotationShape {
  const AnnotationShape({
    required this.id,
    required this.tool,
    required this.points,
    this.color = 0xfff59e0b,
    this.width = 3,
    this.text = '',
  });
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
      AnnotationShape(
        id: value['id'] as String,
        tool: AnnotationTool.values.byName(value['tool'] as String),
        points: List.unmodifiable(
          (value['points'] as List).map(
            (p) =>
                AnnotationPoint.fromJson(Map<String, dynamic>.from(p as Map)),
          ),
        ),
        color: value['color'] as int,
        width: value['width'] as int,
        text: value['text'] as String? ?? '',
      );
}

class AnnotationCanvas {
  const AnnotationCanvas({
    this.canvasId = '',
    this.sourceKey = '',
    this.participantId = '',
    this.shapes = const [],
    this.embeddedInVideo = false,
  });
  final String canvasId, sourceKey, participantId;
  final List<AnnotationShape> shapes;

  /// True when the teacher's system drawing window is captured in the video.
  /// Receivers must not draw the same vector marks a second time.
  final bool embeddedInVideo;
  bool get active => sourceKey.isNotEmpty;
  factory AnnotationCanvas.fromJson(Map<String, dynamic> value) =>
      AnnotationCanvas(
        canvasId: value['canvasId'] as String? ?? '',
        sourceKey: value['sourceKey'] as String? ?? '',
        participantId: value['participantId'] as String? ?? '',
        embeddedInVideo: value['embeddedInVideo'] == true,
        shapes: List.unmodifiable(
          (value['shapes'] as List? ?? []).map(
            (s) =>
                AnnotationShape.fromJson(Map<String, dynamic>.from(s as Map)),
          ),
        ),
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
