import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

class RealtimeRoomState {
  RealtimeRoomState({
    required this.media,
    required this.chat,
    required List<MediaParticipant> participants,
    required this.capabilities,
  }) : participants = List.unmodifiable(participants);

  final MediaSessionState media;
  final ChatConnectionState? chat;
  final List<MediaParticipant> participants;
  final RealtimeRoomCapabilities capabilities;

  bool get isConnected =>
      media == MediaSessionState.connected &&
      (chat == null || chat == ChatConnectionState.connected);
  bool get isReconnecting =>
      media == MediaSessionState.reconnecting ||
      chat == ChatConnectionState.reconnecting;
}

class RealtimeRoomCapabilities {
  const RealtimeRoomCapabilities({required this.media, required this.chat});

  final MediaCapabilities media;
  final ChatCapabilities? chat;

  bool get canChat =>
      chat?.canSendMessage == true ||
      (media.canSendData && media.canReceiveData);
}
