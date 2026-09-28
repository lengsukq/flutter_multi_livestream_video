import 'agora_chat_join_info.dart';

typedef AgoraChatEngineFactory = Future<AgoraChatEngine> Function();
typedef AgoraChatTokenProvider = Future<AgoraChatJoinInfo> Function();

abstract interface class AgoraChatEngine {
  Future<void> connect(
    AgoraChatJoinInfo info,
    AgoraChatEngineEvents events, {
    AgoraChatTokenProvider? tokenProvider,
  });

  Future<void> sendMessage(String message);
  Future<void> deleteMessage(String messageId);
  Future<void> disconnectUser(String userId);
  Future<void> disconnect();
  Future<void> dispose();
}

class AgoraChatEngineEvents {
  const AgoraChatEngineEvents({
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
