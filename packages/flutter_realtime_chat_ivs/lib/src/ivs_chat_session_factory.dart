import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

import 'ivs_chat_engine.dart';
import 'ivs_chat_join_info.dart';
import 'ivs_chat_session.dart';

class IvsChatSessionFactory implements ChatSessionFactory {
  const IvsChatSessionFactory({this.engineFactory = createNativeIvsChatEngine});

  final IvsChatEngineFactory engineFactory;

  @override
  String get providerId => IvsChatJoinInfo.providerIdValue;

  @override
  IvsChatJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      IvsChatJoinInfo.fromJson(json);

  @override
  ChatSession createSession(ChatJoinInfo joinInfo) {
    if (joinInfo is! IvsChatJoinInfo || joinInfo.providerId != providerId) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'IVS Chat session cannot use these credentials.',
        providerId: IvsChatJoinInfo.providerIdValue,
      );
    }
    return IvsChatSession(role: joinInfo.role, engineFactory: engineFactory);
  }
}
