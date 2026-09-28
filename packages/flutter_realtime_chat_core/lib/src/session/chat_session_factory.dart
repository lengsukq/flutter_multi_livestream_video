import '../model/chat_error.dart';
import 'chat_join_info.dart';
import 'chat_session.dart';

abstract class ChatSessionFactory {
  String get providerId;
  ChatJoinInfo parseJoinInfo(Map<String, dynamic> json);
  ChatSession createSession(ChatJoinInfo joinInfo);
}

class ChatRegistry {
  ChatRegistry([Iterable<ChatSessionFactory> factories = const []]) {
    for (final factory in factories) {
      register(factory);
    }
  }

  static final ChatRegistry global = ChatRegistry();

  final Map<String, ChatSessionFactory> _factories = {};

  Iterable<String> get providerIds => _factories.keys;

  void register(ChatSessionFactory factory) {
    final id = factory.providerId.trim().toLowerCase();
    if (id.isEmpty) {
      throw ArgumentError.value(
        factory.providerId,
        'factory.providerId',
        'Chat provider id must not be empty.',
      );
    }
    _factories[id] = factory;
  }

  bool unregister(String providerId) =>
      _factories.remove(providerId.trim().toLowerCase()) != null;

  ChatSessionFactory? lookup(String providerId) =>
      _factories[providerId.trim().toLowerCase()];

  ChatSessionFactory require(String providerId) {
    final factory = lookup(providerId);
    if (factory == null) {
      throw ChatError(
        code: ChatErrorCode.providerNotRegistered,
        message:
            'No chat adapter is registered for provider "$providerId". '
            'Registered providers: ${providerIds.join(', ')}.',
        providerId: providerId,
      );
    }
    return factory;
  }
}
