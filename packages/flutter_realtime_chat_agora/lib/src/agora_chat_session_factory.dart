import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'agora_chat_engine.dart';
import 'agora_chat_engine_factory.dart';
import 'agora_chat_join_info.dart';
import 'agora_chat_session.dart';

class AgoraChatSessionFactory implements ChatSessionFactory {
  const AgoraChatSessionFactory({
    this.maxMessages = 500,
    this.engineFactory = createDefaultAgoraChatEngine,
  }) : assert(maxMessages > 0, 'maxMessages must be positive');

  final int maxMessages;
  final AgoraChatEngineFactory engineFactory;

  @override
  String get providerId => AgoraChatJoinInfo.providerIdValue;

  @override
  AgoraChatJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      AgoraChatJoinInfo.fromJson(json);

  @override
  ChatSession createSession(ChatJoinInfo joinInfo) {
    if (joinInfo is! AgoraChatJoinInfo || joinInfo.providerId != providerId) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Agora Chat session cannot use these credentials.',
        providerId: AgoraChatJoinInfo.providerIdValue,
      );
    }
    return AgoraChatSession(
      role: joinInfo.role,
      engineFactory: engineFactory,
      maxMessages: maxMessages,
    );
  }
}
