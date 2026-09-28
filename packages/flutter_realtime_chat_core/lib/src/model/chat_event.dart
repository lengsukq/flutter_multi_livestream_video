import 'chat_error.dart';
import 'chat_message.dart';
import 'chat_state.dart';

sealed class ChatEvent {
  const ChatEvent();
}

class ChatStateChanged extends ChatEvent {
  const ChatStateChanged(this.state);
  final ChatConnectionState state;
}

class ChatMessageReceived extends ChatEvent {
  const ChatMessageReceived(this.message);
  final ChatMessage message;
}

class ChatMessageDeleted extends ChatEvent {
  const ChatMessageDeleted(this.messageId);
  final String messageId;
}

class ChatUserDisconnected extends ChatEvent {
  const ChatUserDisconnected(this.userId);
  final String userId;
}

class ChatFailureEvent extends ChatEvent {
  const ChatFailureEvent(this.error);
  final ChatError error;
}
