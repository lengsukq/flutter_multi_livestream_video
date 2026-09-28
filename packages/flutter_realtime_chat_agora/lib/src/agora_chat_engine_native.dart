import 'dart:async';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';

import 'agora_chat_engine.dart';
import 'agora_chat_join_info.dart';

Future<AgoraChatEngine> createDefaultAgoraChatEngine() async =>
    _AgoraSdkChatEngine();

class _AgoraSdkChatEngine implements AgoraChatEngine {
  static const _handlerId = 'flutter_realtime_chat_agora';

  AgoraChatEngineEvents _events = const AgoraChatEngineEvents();
  AgoraChatTokenProvider? _tokenProvider;
  AgoraChatJoinInfo? _info;
  bool _connected = false;
  bool _disposed = false;
  bool _refreshing = false;

  ChatClient get _client => ChatClient.getInstance;

  @override
  Future<void> connect(
    AgoraChatJoinInfo info,
    AgoraChatEngineEvents events, {
    AgoraChatTokenProvider? tokenProvider,
  }) async {
    if (_disposed) throw StateError('Agora Chat engine is disposed.');
    _events = events;
    _tokenProvider = tokenProvider;
    _info = info;
    _events.onConnecting?.call(false);

    await _client.init(
      ChatOptions.withAppKey(
        info.appKey,
        autoLogin: false,
        messagesReceiveCallbackIncludeSend: true,
      ),
    );
    await _client.startCallback();
    _client.addConnectionEventHandler(
      _handlerId,
      ConnectionEventHandler(
        onConnected: () {
          if (_connected) _events.onConnected?.call();
        },
        onDisconnected: () {
          if (_connected) _events.onConnecting?.call(true);
        },
        onUserAuthenticationFailed: () =>
            _events.onError?.call(401, 'Agora Chat authentication failed.'),
        onUserDidForbidByServer: () =>
            _events.onError?.call(403, 'Agora Chat user was forbidden.'),
        onUserDidRemoveFromServer: () {
          _connected = false;
          _events.onDisconnected?.call('userRemoved');
        },
        onUserKickedByOtherDevice: () {
          _connected = false;
          _events.onDisconnected?.call('kickedByOtherDevice');
        },
        onTokenWillExpire: () => unawaited(_refreshToken()),
        onTokenDidExpire: () => unawaited(_refreshToken()),
      ),
    );
    _client.chatManager.addEventHandler(
      _handlerId,
      ChatEventHandler(
        onMessagesReceived: (messages) {
          for (final message in messages) {
            _emitMessage(message);
          }
        },
        onMessagesRecalled: (messages) {
          for (final message in messages) {
            final id = message.msgId.trim();
            if (id.isNotEmpty) _events.onMessageDeleted?.call(id);
          }
        },
      ),
    );
    _client.chatRoomManager.addEventHandler(
      _handlerId,
      ChatRoomEventHandler(
        onRemovedFromChatRoom: (roomId, _, participant, __) {
          if (roomId != info.chatRoomId) return;
          final removed = participant?.trim();
          if (removed != null && removed.isNotEmpty) {
            _events.onUserDisconnected?.call(removed);
          }
          if (removed == null || removed == info.providerUserId) {
            _connected = false;
            _events.onDisconnected?.call('removedFromChatRoom');
          }
        },
        onChatRoomDestroyed: (roomId, _) {
          if (roomId != info.chatRoomId) return;
          _connected = false;
          _events.onDisconnected?.call('chatRoomDestroyed');
        },
      ),
    );

    await _client.loginWithToken(info.providerUserId, info.token);
    await _client.chatRoomManager.joinChatRoom(info.chatRoomId);
    _connected = true;
    _events.onConnected?.call();
  }

  @override
  Future<void> sendMessage(String message) async {
    final info = _requireInfo();
    final outgoing = ChatMessage.createTxtSendMessage(
      targetId: info.chatRoomId,
      content: message,
      chatType: ChatType.ChatRoom,
    );
    outgoing.attributes = <String, dynamic>{
      'userId': info.userId,
      'displayName': info.displayName,
      'participantId': info.participantId,
    };
    await _client.chatManager.sendMessage(outgoing);
    // The option messagesReceiveCallbackIncludeSend normally echoes this
    // message. Emit here as well; ChatSession de-duplicates by message id.
    _emitMessage(outgoing);
  }

  @override
  Future<void> deleteMessage(String messageId) async =>
      throw UnsupportedError('Agora Chat moderation is not enabled.');

  @override
  Future<void> disconnectUser(String userId) async =>
      throw UnsupportedError('Agora Chat moderation is not enabled.');

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    final info = _info;
    if (info != null) {
      try {
        await _client.chatRoomManager.leaveChatRoom(info.chatRoomId);
      } catch (_) {
        // Logout below still closes this local session.
      }
    }
    try {
      await _client.logout(false);
    } finally {
      _connected = false;
      _events.onDisconnected?.call('clientDisconnect');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _client.chatManager.removeEventHandler(_handlerId);
    _client.chatRoomManager.removeEventHandler(_handlerId);
    _client.removeConnectionEventHandler(_handlerId);
    _disposed = true;
    _tokenProvider = null;
    _info = null;
  }

  Future<void> _refreshToken() async {
    if (_refreshing || _disposed) return;
    final provider = _tokenProvider;
    if (provider == null) {
      _events.onError?.call(401, 'Agora Chat token expired.');
      return;
    }
    _refreshing = true;
    try {
      final refreshed = await provider();
      _info = refreshed;
      await _client.renewAgoraToken(refreshed.token);
      _events.onConnected?.call();
    } catch (error) {
      _events.onError?.call(401, error.toString());
    } finally {
      _refreshing = false;
    }
  }

  void _emitMessage(ChatMessage message) {
    final info = _info;
    if (info == null || message.chatType != ChatType.ChatRoom) return;
    if (message.conversationId != null &&
        message.conversationId != info.chatRoomId &&
        message.to != info.chatRoomId) {
      return;
    }
    final body = message.body;
    if (body is! ChatTextMessageBody) return;
    final id = message.msgId.trim();
    if (id.isEmpty) return;
    final attributes = message.attributes ?? const <String, dynamic>{};
    final logicalUserId =
        attributes['userId']?.toString().trim() ?? message.from?.trim() ?? '';
    if (logicalUserId.isEmpty) return;
    _events.onMessage?.call({
      'id': id,
      'userId': logicalUserId,
      'displayName':
          attributes['displayName']?.toString().trim() ?? logicalUserId,
      'message': body.content,
      'timestampMs': message.serverTime > 0
          ? message.serverTime
          : DateTime.now().millisecondsSinceEpoch,
      'attributes': <String, String>{
        'providerUserId': message.from ?? '',
        if (attributes['participantId'] != null)
          'participantId': attributes['participantId'].toString(),
      },
    });
  }

  AgoraChatJoinInfo _requireInfo() {
    final info = _info;
    if (!_connected || info == null) {
      throw StateError('Agora Chat engine is not connected.');
    }
    return info;
  }
}
