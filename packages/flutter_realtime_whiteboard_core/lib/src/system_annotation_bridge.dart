import 'dart:async';
import 'system_annotation_capabilities.dart';
import 'system_annotation_viewport.dart';

abstract interface class SystemAnnotationBridge {
  bool get active;
  Object? get error;
  Stream<void> get changes;
  Future<SystemAnnotationCapabilities> probe();
  Future<void> requestPermission();
  Future<void> start({
    SystemAnnotationViewport viewport = const SystemAnnotationViewport(),
    String languageCode = 'en',
  });
  Future<void> stop();
  Future<void> dispose();
}
