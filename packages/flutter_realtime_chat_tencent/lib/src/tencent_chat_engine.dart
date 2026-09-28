import 'tencent_chat_join_info.dart';

typedef TencentChatEngineFactory = Future<TencentChatEngine> Function();
typedef TencentChatTokenProvider = Future<TencentChatJoinInfo> Function();

abstract interface class TencentChatEngine {
  Future<void> connect(
    TencentChatJoinInfo info,
    TencentChatEngineEvents events, {
    TencentChatTokenProvider? tokenProvider,
  });

  Future<void> sendMessage(String message);
  Future<void> deleteMessage(String messageId);
  Future<void> disconnectUser(String userId);
  Future<void> disconnect();
  Future<void> dispose();
}

class TencentChatEngineEvents {
  const TencentChatEngineEvents({
    this.onConnecting,
    this.onConnected,
    this.onDisconnected,
    this.onMessage,
    this.onMessageDeleted,
    this.onUserDisconnected,
    this.onError,
  });

  final void Function(bool reconnecting)? onConnecting;
  final void Function()? onConnected;
  final void Function(String reason)? onDisconnected;
  final void Function(Map<String, Object?> message)? onMessage;
  final void Function(String messageId)? onMessageDeleted;
  final void Function(String userId)? onUserDisconnected;
  final void Function(int code, String message)? onError;
}
