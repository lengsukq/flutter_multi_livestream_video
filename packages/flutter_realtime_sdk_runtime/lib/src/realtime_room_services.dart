import 'realtime_video_effects.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'realtime_client.dart';

typedef RealtimeRecordingSessionFactory =
    MediaCloudRecordingSession? Function(MediaRoomSession room);
typedef RealtimeStandaloneChatProvisionerFactory =
    StandaloneChatProvisioner Function();

/// Factories return room-scoped objects owned by the SDK. Shared underlying
/// transports injected by the host remain host-owned.
class RealtimeRoomServices {
  const RealtimeRoomServices({
    this.mediaClientFactory,
    this.chatClientFactory,
    this.standaloneChatProvisionerFactory,
    this.interactionControlPlaneFactory,
    this.recordingSessionFactory,
    this.videoEffectsFactory,
  });
  final RealtimeMediaClientFactory? mediaClientFactory;
  final RealtimeChatClientFactory? chatClientFactory;
  final RealtimeStandaloneChatProvisionerFactory?
  standaloneChatProvisionerFactory;
  final InteractionControlPlaneFactory? interactionControlPlaneFactory;
  final RealtimeVideoEffectsFactory? videoEffectsFactory;
  final RealtimeRecordingSessionFactory? recordingSessionFactory;
}
