import 'dart:async';
import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

/// Availability of an actual system overlay, distinct from in-app annotation.
class SystemAnnotationCapabilities {
  const SystemAnnotationCapabilities({
    required this.supported,
    this.permissionRequired = false,
    this.reason = '',
  });
  final bool supported, permissionRequired;
  final String reason;
}

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

abstract interface class SystemAnnotationBridge {
  bool get active;
  Object? get error;
  Stream<void> get changes;
  Future<SystemAnnotationCapabilities> probe();
  Future<void> requestPermission();
  Future<void> start({SystemAnnotationViewport viewport = const SystemAnnotationViewport(), String languageCode = 'en'});
  Future<void> stop();
  Future<void> dispose();
}

class UnavailableSystemAnnotationBridge implements SystemAnnotationBridge {
  const UnavailableSystemAnnotationBridge();
  @override bool get active => false;
  @override Object? get error => null;
  @override Stream<void> get changes => const Stream.empty();
  @override Future<SystemAnnotationCapabilities> probe() async => const SystemAnnotationCapabilities(supported: false, reason: 'System annotation is not registered');
  @override Future<void> requestPermission() async => _unsupported();
  @override Future<void> start({SystemAnnotationViewport viewport = const SystemAnnotationViewport(), String languageCode = 'en'}) async => _unsupported();
  @override Future<void> stop() async {}
  @override Future<void> dispose() async {}
  Never _unsupported() => throw const RealtimeException(code: RealtimeErrorCode.unsupportedFeature, message: 'annotation.system.unregistered');
}
