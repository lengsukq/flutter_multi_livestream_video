import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_chat_room.dart';
import 'realtime_event.dart';
import 'realtime_moderation.dart';
import 'realtime_request.dart';
import 'realtime_room.dart';

class RealtimeConnectionCapabilities {
  const RealtimeConnectionCapabilities({this.media, this.chat});

  final MediaCapabilities? media;
  final ChatCapabilities? chat;

  bool get canChat => chat?.canSendMessage == true;
}

class RealtimeConnectionState {
  const RealtimeConnectionState({this.media, this.chat});

  final MediaSessionState? media;
  final ChatConnectionState? chat;

  bool get isConnected =>
      (media == null || media == MediaSessionState.connected) &&
      (chat == null || chat == ChatConnectionState.connected);

  bool get isReconnecting =>
      media == MediaSessionState.reconnecting ||
      chat == ChatConnectionState.reconnecting;

  bool get isTerminal =>
      (media == null || media!.isTerminal) &&
      (chat == null || chat!.isTerminal);
}

class RealtimeConnection {
  RealtimeConnection._({
    required this.experience,
    this.mediaRoom,
    this.chatRoom,
    void Function()? disposeAuxiliary,
  }) : _disposeAuxiliary = disposeAuxiliary;

  factory RealtimeConnection.media({
    required RealtimeExperience experience,
    required RealtimeRoom room,
  }) => RealtimeConnection._(experience: experience, mediaRoom: room);

  factory RealtimeConnection.chat({
    required RealtimeChatRoom room,
    void Function()? disposeAuxiliary,
  }) => RealtimeConnection._(
    experience: RealtimeExperience.chat,
    chatRoom: room,
    disposeAuxiliary: disposeAuxiliary,
  );

  final RealtimeExperience experience;
  final RealtimeRoom? mediaRoom;
  final RealtimeChatRoom? chatRoom;
  final void Function()? _disposeAuxiliary;
  bool _disposed = false;

  String get roomCode => mediaRoom?.roomCode ?? chatRoom!.roomCode;
  String get providerId => mediaRoom?.providerId ?? chatRoom!.providerId;
  String? get mediaProviderId => mediaRoom?.providerId;
  String? get mediaEngineProviderId => mediaRoom?.engineProviderId;
  String? get chatProviderId => chatSession?.providerId;

  ChatSession? get chatSession => mediaRoom?.chat ?? chatRoom?.session;

  RealtimeChatModeration? get chatModeration =>
      mediaRoom?.chatModeration ?? chatRoom?.moderation;

  RealtimeConnectionCapabilities get capabilities =>
      RealtimeConnectionCapabilities(
        media: mediaRoom?.capabilities.media,
        chat: chatSession?.capabilities,
      );

  RealtimeConnectionState get state => RealtimeConnectionState(
    media: mediaRoom?.state.media,
    chat: chatSession?.state,
  );

  Stream<RealtimeConnectionState> get states {
    final media = mediaRoom;
    if (media != null) {
      return media.states.map(
        (value) =>
            RealtimeConnectionState(media: value.media, chat: value.chat),
      );
    }
    return chatRoom!.session.states.map(
      (value) => RealtimeConnectionState(chat: value),
    );
  }

  Stream<RealtimeEvent> get events {
    final media = mediaRoom;
    if (media != null) return media.events;
    return chatRoom!.session.events.map(RealtimeChatEvent.new);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      final media = mediaRoom;
      if (media != null) {
        await media.dispose();
      } else {
        await chatRoom!.dispose();
      }
    } finally {
      _disposeAuxiliary?.call();
    }
  }
}
