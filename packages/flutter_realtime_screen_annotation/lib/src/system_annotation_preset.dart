import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_shared_content_preset/flutter_realtime_shared_content_preset.dart';
import 'system_screen_annotation.dart';
import 'system_annotation_room_feature.dart';

class SystemAnnotationPreset
    extends RealtimeFeaturePlugin<SystemAnnotationRoomFeature> {
  const SystemAnnotationPreset();
  static const featureKey = RealtimeFeatureKey<SystemAnnotationRoomFeature>(
    'system-annotation',
  );
  @override
  RealtimeFeatureKey<SystemAnnotationRoomFeature> get key => featureKey;
  @override
  List<RealtimeFeatureKey<Object>> get requiredFeatures => const [
    SharedContentPreset.featureKey,
  ];
  @override
  Future<SystemAnnotationRoomFeature> attach(
    RealtimeFeatureContext context,
  ) async {
    final shared = context
        .feature(SharedContentPreset.featureKey)!
        .sharedContent;
    final controller = SystemScreenAnnotationController(
      annotations: shared.screenAnnotations,
    );
    try {
      await shared.setSystemAnnotations(controller);
    } catch (error, stack) {
      final cleanup = Cleanup();
      await cleanup.run('system.annotation', controller.dispose);
      cleanup.finish(domain: 'annotation', cause: error);
      Error.throwWithStackTrace(error, stack);
    }
    return SystemAnnotationRoomFeature(shared, controller);
  }

  @override
  Future<void> detach(SystemAnnotationRoomFeature feature) => feature.dispose();
}
