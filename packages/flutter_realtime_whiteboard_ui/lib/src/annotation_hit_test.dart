import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';

/// Finds the visually topmost vector mark touched by a screen-space eraser.
/// Coordinates are in the same (possibly unbounded) scene used by the painter,
/// so zooming or panning never changes which mark a gesture deletes.
AnnotationShape? findErasableShape(
  Iterable<AnnotationShape> shapes,
  Offset point,
  Size size, {
  double radius = 14,
  String fontFamily = '',
}) {
  if (size.isEmpty) return null;
  final scale = size.shortestSide / 720;
  for (final shape in shapes.toList().reversed) {
    if (shape.points.isEmpty || shape.tool == AnnotationTool.eraser) continue;
    final points = shape.points
        .map((p) => Offset(p.x * size.width, p.y * size.height))
        .toList(growable: false);
    final start = points.first;
    final end = points.last;
    final threshold = radius + math.max(1, shape.width * scale) / 2;
    bool near(Offset a, Offset b) =>
        _distanceToSegment(point, a, b) <= threshold;
    switch (shape.tool) {
      case AnnotationTool.pen:
      case AnnotationTool.highlight:
        if (points.length == 1 && (point - start).distance <= threshold) {
          return shape;
        }
        for (var i = 1; i < points.length; i++) {
          if (near(points[i - 1], points[i])) return shape;
        }
      case AnnotationTool.circle:
        final rect = Rect.fromPoints(start, end);
        if (rect.width <= 1 || rect.height <= 1) {
          if (near(start, end)) return shape;
          continue;
        }
        Offset ellipse(double angle) => Offset(
          rect.center.dx + rect.width / 2 * math.cos(angle),
          rect.center.dy + rect.height / 2 * math.sin(angle),
        );
        var previous = ellipse(0);
        for (var i = 1; i <= 64; i++) {
          final next = ellipse(i * 2 * math.pi / 64);
          if (near(previous, next)) return shape;
          previous = next;
        }
      case AnnotationTool.arrow:
        if (near(start, end)) return shape;
        final direction = math.atan2(end.dy - start.dy, end.dx - start.dx);
        final length = math.max(8.0, 18 * scale);
        for (final delta in [-.5, .5]) {
          final corner =
              end -
              Offset(math.cos(direction + delta), math.sin(direction + delta)) *
                  length;
          if (near(end, corner)) return shape;
        }
      case AnnotationTool.text:
        final painter = TextPainter(
          text: TextSpan(
            text: shape.text,
            style: TextStyle(
              fontFamily: fontFamily.isEmpty ? null : fontFamily,
              fontSize: math.max(10, 22 * scale),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: size.width);
        if (Rect.fromLTWH(
          start.dx - radius,
          start.dy - radius,
          painter.width + 2 * radius,
          painter.height + 2 * radius,
        ).contains(point)) {
          return shape;
        }
      case AnnotationTool.eraser:
        break;
    }
  }
  return null;
}

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final segment = end - start;
  final length = segment.distanceSquared;
  if (length < 1e-6) return (point - start).distance;
  final t =
      (((point.dx - start.dx) * segment.dx +
                  (point.dy - start.dy) * segment.dy) /
              length)
          .clamp(0.0, 1.0);
  return (point - (start + segment * t)).distance;
}
