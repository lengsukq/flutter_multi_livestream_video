// ignore_for_file: prefer_initializing_formals

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_rtc/flutter_realtime_chat_rtc.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_adapter.dart';
import 'realtime_room.dart';
import 'realtime_requirements.dart';
import 'realtime_chat_room.dart';

typedef RealtimeTokenProvider = Future<String?> Function();
typedef RealtimeMediaClientFactory = MediaClient Function();
typedef RealtimeChatClientFactory = ChatClient Function();

/// Recommended application-level entry point for realtime rooms.
///
/// Lower-level [MediaClient] and [ChatClient] remain available for applications
/// that need to own media or product-chat orchestration themselves.
class RealtimeClient {
  RealtimeClient({
    this.backendUrl,
    required this.mediaAdapters,
    ChatRegistry? chatRegistry,
    RealtimeTokenProvider? tokenProvider,
    RealtimeMediaClientFactory? mediaClientFactory,
    RealtimeChatClientFactory? chatClientFactory,
  }) : chatRegistry = chatRegistry ?? ChatRegistry(),
       _tokenProvider = tokenProvider,
       _mediaClientFactory = mediaClientFactory,
       _chatClientFactory = chatClientFactory;

  final String? backendUrl;
  final RealtimeMediaAdapters mediaAdapters;
  final ChatRegistry chatRegistry;
  final RealtimeTokenProvider? _tokenProvider;
  final RealtimeMediaClientFactory? _mediaClientFactory;
  final RealtimeChatClientFactory? _chatClientFactory;

  ChatClient newChatClient({ChatProvisioner? provisioner}) =>
      _chatClientFactory?.call() ??
      (backendUrl == null
          ? ChatClient.direct(registry: chatRegistry, provisioner: provisioner)
          : ChatClient(
              backendUrl: backendUrl!,
              registry: chatRegistry,
              tokenProvider: _tokenProvider,
            ));

  Future<RealtimeChatRoom> connectChatDirect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) async {
    final client = ChatClient.direct(registry: chatRegistry);
    try {
      final room = await client.connect(
        joinInfo,
        credentialProvider: credentialProvider,
      );
      return RealtimeChatRoom(room: room, disposeClient: client.dispose);
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

  Future<RealtimeChatRoom> createChatRoom({
    required StandaloneChatProvisioner provisioner,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) async {
    final client = ChatClient.direct(
      registry: chatRegistry,
      provisioner: provisioner,
    );
    try {
      final room = await client.createStandaloneRoom(
        userId: userId,
        displayName: displayName,
        role: role,
        roomCode: roomCode,
      );
      return RealtimeChatRoom(room: room, disposeClient: client.dispose);
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

  Future<RealtimeChatRoom> joinChatRoom({
    required StandaloneChatProvisioner provisioner,
    required String roomCode,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.participant,
  }) async {
    final client = ChatClient.direct(
      registry: chatRegistry,
      provisioner: provisioner,
    );
    try {
      final room = await client.joinStandaloneRoom(
        roomCode: roomCode,
        userId: userId,
        displayName: displayName,
        role: role,
      );
      return RealtimeChatRoom(room: room, disposeClient: client.dispose);
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

  MediaClient newMediaClient() =>
      _mediaClientFactory?.call() ??
      (backendUrl == null
          ? MediaClient.direct(registry: mediaAdapters.registry)
          : MediaClient(
              backendUrl: backendUrl!,
              registry: mediaAdapters.registry,
              tokenProvider: _tokenProvider,
            ));

  /// Adopts media joined from any trusted provisioning mechanism.
  Future<RealtimeRoom> joinDirect(
    MediaJoinInfo joinInfo, {
    ChatJoinInfo? chatJoinInfo,
    ChatCredentialProvider? chatCredentialProvider,
  }) async {
    final client = newMediaClient();
    try {
      final room = await client.join(joinInfo);
      return await _resolveRoom(
        client,
        room,
        directChatJoinInfo: chatJoinInfo,
        directChatCredentialProvider: chatCredentialProvider,
      );
    } catch (_) {
      client.dispose();
      rethrow;
    }
  }

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
    MediaRoomSession room, {
    ChatJoinInfo? directChatJoinInfo,
    ChatCredentialProvider? directChatCredentialProvider,
  }) async {
    ChatClient? chatClient;
    ChatRoomSession? productChatRoom;
    RtcDataChatSession? rtcChatRoom;
    try {
      final renderer = mediaAdapters.require(room.providerId).renderer;
      ChatSession? chat;
      final productChatConfigured =
          directChatJoinInfo != null || room.chatProvider != null;
      if (productChatConfigured) {
        if (directChatJoinInfo != null) {
          chatClient = ChatClient.direct(registry: chatRegistry);
          productChatRoom = await chatClient.connect(
            directChatJoinInfo,
            credentialProvider: directChatCredentialProvider,
          );
        } else {
          final url = backendUrl;
          if (_chatClientFactory == null && url == null) {
            throw const ChatError(
              code: ChatErrorCode.unsupportedFeature,
              message:
                  'Product Chat is configured for this room, but no ChatClient '
                  'factory or backend provisioning configuration was supplied.',
            );
          }
          chatClient =
              _chatClientFactory?.call() ??
              ChatClient(
                backendUrl: url!,
                registry: chatRegistry,
                tokenProvider: _tokenProvider,
              );
          productChatRoom = await chatClient.connectRoom(
            roomCode: room.roomCode,
            participantId: room.participantId,
            participantCredential: room.participantCredential,
            roomOwnerCredential: room.roomOwnerCredential,
          );
        }
        if (room.chatProvider != null &&
            productChatRoom.session.providerId != room.chatProvider) {
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
