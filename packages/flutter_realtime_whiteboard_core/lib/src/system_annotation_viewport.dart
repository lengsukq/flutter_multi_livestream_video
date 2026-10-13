import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

/// A normalized overlay viewport on the primary shared display. Hosts sharing
/// one window may supply its display-relative rectangle instead.
class SystemAnnotationViewport {
  const SystemAnnotationViewport({
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
  });
  final double x, y, width, height;
  Map<String, double> toJson() {
    if (![x, y, width, height].every((v) => v.isFinite) ||
        x < 0 ||
        y < 0 ||
        width <= 0 ||
        height <= 0 ||
        x + width > 1 ||
        y + height > 1) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Viewport must be inside the primary display.',
      );
    }
    return {'x': x, 'y': y, 'width': width, 'height': height};
  }
}
