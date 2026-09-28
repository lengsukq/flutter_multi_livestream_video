import '../model/chat_error.dart';
import '../session/chat_join_info.dart';
import '../session/chat_room_session.dart';
import '../session/chat_session_factory.dart';
import 'chat_backend_client.dart';
import 'chat_backend_config.dart';

class ChatClient {
  ChatClient({
    required String backendUrl,
    ChatRegistry? registry,
    ChatBackendTokenProvider? tokenProvider,
    ChatBackendHeadersProvider? headersProvider,
    Duration requestTimeout = const Duration(seconds: 15),
  }) : this.withConfig(
         ChatBackendConfig.fromUrl(
           backendUrl,
           tokenProvider: tokenProvider,
           headersProvider: headersProvider,
           requestTimeout: requestTimeout,
         ),
         registry: registry,
       );

  ChatClient.withConfig(
    ChatBackendConfig config, {
    ChatRegistry? registry,
    ChatBackendClient? backend,
  }) : registry = registry ?? ChatRegistry.global,
       backend = backend ?? ChatBackendClient(config);

  final ChatRegistry registry;
  final ChatBackendClient backend;

  Future<ChatRoomSession> connectRoom({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  }) async {
    Future<ChatJoinInfo> credentials() async {
      final response = await backend.issueToken(
        roomCode: roomCode,
        participantId: participantId,
        participantCredential: participantCredential,
      );
      final factory = registry.require(response.providerId);
      final joinInfo = factory.parseJoinInfo(response.json);
      if (joinInfo.providerId.trim().toLowerCase() != response.providerId ||
          joinInfo.roomCode != response.roomCode ||
          joinInfo.participantId != participantId) {
        throw ChatError(
          code: ChatErrorCode.invalidJoinInfo,
          message:
              'Chat adapter join information does not match the backend response.',
          providerId: response.providerId,
        );
      }
      return joinInfo;
    }

    final joinInfo = await credentials();
    final factory = registry.require(joinInfo.providerId);
    final session = factory.createSession(joinInfo);
    try {
      await session.connect(joinInfo, credentialProvider: credentials);
      return ChatRoomSession(
        roomCode: joinInfo.roomCode,
        participantId: joinInfo.participantId,
        userId: joinInfo.userId,
        role: joinInfo.role,
        session: session,
      );
    } catch (_) {
      await session.dispose();
      rethrow;
    }
  }

  void dispose() => backend.dispose();
}
