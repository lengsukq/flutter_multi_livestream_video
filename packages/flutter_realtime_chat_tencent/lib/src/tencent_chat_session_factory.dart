import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'tencent_chat_engine.dart';
import 'tencent_chat_engine_native.dart';
import 'tencent_chat_join_info.dart';
import 'tencent_chat_session.dart';

class TencentChatSessionFactory implements ChatSessionFactory {
  const TencentChatSessionFactory({
    this.engineFactory = createDefaultTencentChatEngine,
  });

  final TencentChatEngineFactory engineFactory;

  @override
  String get providerId => TencentChatJoinInfo.providerIdValue;

  @override
  TencentChatJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      TencentChatJoinInfo.fromJson(json);

  @override
  ChatSession createSession(ChatJoinInfo joinInfo) {
    if (joinInfo is! TencentChatJoinInfo || joinInfo.providerId != providerId) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Tencent Chat session cannot use these credentials.',
        providerId: TencentChatJoinInfo.providerIdValue,
      );
    }
    return TencentChatSession(
      role: joinInfo.role,
      engineFactory: engineFactory,
    );
  }
}
