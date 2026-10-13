import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'annotation_point.dart';
import 'annotation_tool.dart';

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
