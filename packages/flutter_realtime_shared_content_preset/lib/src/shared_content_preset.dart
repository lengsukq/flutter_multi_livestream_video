import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'shared_content_controller.dart';
import 'room_annotation_coordinator.dart';

class SharedContentRoomFeature {
  SharedContentRoomFeature(RealtimeFeatureContext context) {
    final classroom = context.feature(ClassroomPreset.featureKey)!;
    sharedContent = SharedContentController(media: context.media.session, classroom: classroom);
    annotations = RoomAnnotationCoordinator(context.media.session, classroom, (error) => context.reportError?.call(error, StackTrace.current));
  }
  late final SharedContentController sharedContent;
  late final RoomAnnotationCoordinator annotations;
  Future<void> dispose() async {
    final cleanup = Cleanup();
    await cleanup.run('annotation', annotations.dispose);
    await cleanup.run('sharedContent', sharedContent.dispose);
    cleanup.finish(domain: 'sharedContent');
  }
}

class SharedContentPreset extends RealtimeFeaturePlugin<SharedContentRoomFeature> {
  const SharedContentPreset();
  static const featureKey = RealtimeFeatureKey<SharedContentRoomFeature>('shared-content');
  @override RealtimeFeatureKey<SharedContentRoomFeature> get key => featureKey;
  @override List<RealtimeFeatureKey<Object>> get requiredFeatures => const [ClassroomPreset.featureKey];
  @override SharedContentRoomFeature attach(RealtimeFeatureContext context) => SharedContentRoomFeature(context);
  @override Future<void> detach(SharedContentRoomFeature feature) => feature.dispose();
}

extension RealtimeRoomSharedContentExtension on RealtimeRoom {
  SharedContentController? get sharedContent => features.get(SharedContentPreset.featureKey)?.sharedContent;
}
