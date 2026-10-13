import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'demo_provider_catalog.dart';

/// Demo explicitly elects every optional capability it showcases.
Realtime createDemoRealtime(String backendUrl, {String appToken = ''}) =>
    Realtime(
      providers: createDemoProviders(),
      backendUrl: backendUrl,
      services: RealtimeRoomServices(
        videoEffectsFactory: DefaultRealtimeVideoEffects.new,
      ),
      tokenProvider: appToken.trim().isEmpty ? null : () async => appToken,
      featurePlugins: const [
        ClassroomPreset(),
        SharedContentPreset(),
        SystemAnnotationPreset(),
        LivePreset(),
      ],
    );
