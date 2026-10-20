import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

/// Scene coordinates relative to a shared reference canvas. Screen annotation
/// overlays remain inside [0, 1]; unbounded whiteboards can extend beyond it.
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
