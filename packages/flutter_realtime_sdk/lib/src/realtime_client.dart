// ignore_for_file: prefer_initializing_formals

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_rtc/flutter_realtime_chat_rtc.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_adapter.dart';
import 'realtime_room.dart';
import 'realtime_requirements.dart';

typedef RealtimeTokenProvider = Future<String?> Function();
typedef RealtimeMediaClientFactory = MediaClient Function();
typedef RealtimeChatClientFactory = ChatClient Function();

/// Recommended application-level entry point for realtime rooms.
///
/// Lower-level [MediaClient] and [ChatClient] remain available for applications
/// that need to own media or product-chat orchestration themselves.
class RealtimeClient {
  RealtimeClient({
    required this.backendUrl,
    required this.mediaAdapters,
    ChatRegistry? chatRegistry,
    RealtimeTokenProvider? tokenProvider,
    RealtimeMediaClientFactory? mediaClientFactory,
    RealtimeChatClientFactory? chatClientFactory,
  }) : chatRegistry = chatRegistry ?? ChatRegistry(),
       _tokenProvider = tokenProvider,
       _mediaClientFactory = mediaClientFactory,
       _chatClientFactory = chatClientFactory,
       assert(backendUrl != '');

  final String backendUrl;
  final RealtimeMediaAdapters mediaAdapters;
  final ChatRegistry chatRegistry;
  final RealtimeTokenProvider? _tokenProvider;
  final RealtimeMediaClientFactory? _mediaClientFactory;
  final RealtimeChatClientFactory? _chatClientFactory;

  MediaClient newMediaClient() =>
      _mediaClientFactory?.call() ??
      MediaClient(
        backendUrl: backendUrl,
        registry: mediaAdapters.registry,
        tokenProvider: _tokenProvider,
      );

  Future<RealtimeRoom> createRoomAndJoinIdentity({
    required MediaIdentity identity,
    MediaRoomMode roomMode = MediaRoomMode.meeting,
    MediaRole? role,
    String? roomCode,
  }) async {
    final client = newMediaClient();
    try {
      final room = await client.createRoomAndJoinIdentity(
        identity: identity,
        roomMode: roomMode,
        role: role,
        roomCode: roomCode,
      );
      return await _resolveRoom(client, room);
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

  Future<RealtimeRoom> joinRoomIdentity({
    required String roomCode,
    required MediaIdentity identity,
    String? roomOwnerCredential,
    MediaRole? role,
  }) async {
    final client = newMediaClient();
    try {
      final room = await client.joinRoomIdentity(
        roomCode: roomCode,
        identity: identity,
        roomOwnerCredential: roomOwnerCredential,
        role: role,
      );
      return await _resolveRoom(client, room);
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

  Future<RealtimeRoom> adopt(MediaClient client, MediaRoomSession room) =>
      _resolveRoom(client, room);

  Future<RealtimeRoom> _resolveRoom(
    MediaClient mediaClient,
    MediaRoomSession room,
  ) async {
    ChatClient? chatClient;
    ChatRoomSession? productChatRoom;
    RtcDataChatSession? rtcChatRoom;
    try {
      final renderer = mediaAdapters.require(room.providerId).renderer;
      ChatSession? chat;
      final productChatConfigured = room.chatProvider != null;
      if (productChatConfigured) {
        chatClient =
            _chatClientFactory?.call() ??
            ChatClient(
              backendUrl: backendUrl,
              registry: chatRegistry,
              tokenProvider: _tokenProvider,
            );
        productChatRoom = await chatClient.connectRoom(
          roomCode: room.roomCode,
          participantId: room.participantId,
          participantCredential: room.participantCredential,
        );
        if (productChatRoom.session.providerId != room.chatProvider) {
          throw ChatError(
            code: ChatErrorCode.invalidJoinInfo,
            message:
                'Backend expected chat provider "${room.chatProvider}" but '
                'issued "${productChatRoom.session.providerId}" credentials.',
            providerId: room.chatProvider,
          );
        }
      }

      chat = resolveChatSessionWithRtcFallback(
        room: room,
        productChatConfigured: productChatConfigured,
        productChatSession: productChatRoom?.session,
      );
      if (chat is RtcDataChatSession) rtcChatRoom = chat;

      _validateRequirements(
        RealtimeCapabilityRequirements.fromBackend(room.backendMetadata),
        media: room.session.capabilities,
        chat: chat?.capabilities,
        providerId: room.providerId,
      );

      return RealtimeRoom(
        media: room,
        renderer: renderer,
        chat: chat,
        productChatRoom: productChatRoom,
        rtcChatRoom: rtcChatRoom,
        disposeClients: () {
          chatClient?.dispose();
          mediaClient.dispose();
        },
      );
    } catch (_) {
      await productChatRoom?.dispose();
      await rtcChatRoom?.dispose();
      chatClient?.dispose();
      await room.dispose();
      mediaClient.dispose();
      rethrow;
    }
  }

  void _validateRequirements(
    RealtimeCapabilityRequirements requirements, {
    required MediaCapabilities media,
    required ChatCapabilities? chat,
    required String providerId,
  }) {
    bool supported(RealtimeCapability value) => switch (value) {
      RealtimeCapability.publishAudio => media.canPublishAudio,
      RealtimeCapability.publishVideo => media.canPublishVideo,
      RealtimeCapability.subscribeVideo => media.canSubscribeVideo,
      RealtimeCapability.screenShare => media.canScreenShare,
      RealtimeCapability.chat =>
        chat?.canSendMessage == true ||
            (media.canSendData && media.canReceiveData),
      RealtimeCapability.listParticipants => media.canListParticipants,
      RealtimeCapability.removeParticipants => media.canRemoveParticipants,
      RealtimeCapability.closeRoom => media.canCloseRoom,
    };

    final missing = requirements.values.where((value) => !supported(value));
    if (missing.isEmpty) return;
    throw MediaError(
      code: MediaErrorCode.unsupportedFeature,
      message:
          'The backend requires unsupported realtime capabilities: '
          '${missing.map((value) => value.name).join(', ')}.',
      providerId: providerId,
      details: missing.map((value) => value.name).toList(growable: false),
    );
  }
}
