import '../model/chat_capabilities.dart';
import '../model/chat_event.dart';
import '../model/chat_message.dart';
import '../model/chat_role.dart';
import '../model/chat_state.dart';
import 'chat_join_info.dart';

abstract class ChatSession {
  String get providerId;
  ChatRole get role;
  ChatCapabilities get capabilities;
  ChatConnectionState get state;
  List<ChatMessage> get messages;
  Stream<ChatConnectionState> get states;
  Stream<List<ChatMessage>> get messageSnapshots;
  Stream<ChatEvent> get events;

  Future<void> connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  });

  Future<void> sendMessage(String message);
  Future<void> deleteMessage(String messageId);
  Future<void> disconnectUser(String userId);
  Future<void> disconnect();
  Future<void> dispose();
}
