import 'package:flutter_realtime_shared_content_preset/flutter_realtime_shared_content_preset.dart';
import 'system_screen_annotation.dart';

/// Owns the system annotation binding, including removal from shared content.
class SystemAnnotationRoomFeature {
  SystemAnnotationRoomFeature(this._shared, this.controller);
  final SharedContentController _shared;
  final SystemScreenAnnotationController controller;
  Future<void>? _disposal;
  Future<void> dispose() => _disposal ??= _shared.removeSystemAnnotations(controller);
}
