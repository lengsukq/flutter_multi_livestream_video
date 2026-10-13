import 'dart:async';
import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'system_annotation_bridge.dart';
import 'system_annotation_capabilities.dart';
import 'system_annotation_viewport.dart';

class UnavailableSystemAnnotationBridge implements SystemAnnotationBridge {
  const UnavailableSystemAnnotationBridge();
  @override
  bool get active => false;
  @override
  Object? get error => null;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<SystemAnnotationCapabilities> probe() async =>
      const SystemAnnotationCapabilities(
        supported: false,
        reason: 'System annotation is not registered',
      );
  @override
  Future<void> requestPermission() async => _unsupported();
  @override
  Future<void> start({
    SystemAnnotationViewport viewport = const SystemAnnotationViewport(),
    String languageCode = 'en',
  }) async => _unsupported();
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  Never _unsupported() => throw const RealtimeException(
    code: RealtimeErrorCode.unsupportedFeature,
    message: 'annotation.system.unregistered',
  );
}
