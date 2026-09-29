import '../model/chat_error.dart';
import '../model/chat_role.dart';
import '../model/chat_room_context.dart';
import '../session/chat_join_info.dart';
import '../session/chat_room_session.dart';
import '../session/chat_session_factory.dart';
import 'chat_backend_client.dart';
import 'chat_backend_config.dart';
import 'chat_provisioner.dart';

class ChatClient {
  ChatClient.direct({ChatRegistry? registry, this.provisioner})
    : registry = registry ?? ChatRegistry.global,
      backend = null;

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
       backend = backend ?? ChatBackendClient(config),
       provisioner = null;

  final ChatRegistry registry;
  final ChatBackendClient? backend;
  final ChatProvisioner? provisioner;

  StandaloneChatProvisioner get _standaloneProvisioner {
    final value = provisioner;
    if (value is StandaloneChatProvisioner) return value;
    throw const ChatError(
      code: ChatErrorCode.unsupportedFeature,
      message:
          'Standalone room creation/join requires a '
          'StandaloneChatProvisioner.',
    );
  }

  Future<ChatRoomSession> createStandaloneRoom({
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) async {
    final controller = _standaloneProvisioner;
    final joinInfo = _parseProvisionedJoinInfo(
      await controller.create(
        userId: userId,
        displayName: displayName,
        role: role,
        roomCode: roomCode,
      ),
    );
    Future<ChatJoinInfo> credentials() async => _parseProvisionedJoinInfo(
      await controller.provision(
        roomCode: joinInfo.roomCode,
        participantId: joinInfo.participantId,
        participantCredential: joinInfo.json['participantCredential']
            ?.toString(),
      ),
      expected: joinInfo,
    );
    return connect(joinInfo, credentialProvider: credentials);
  }

  Future<ChatRoomSession> joinStandaloneRoom({
    required String roomCode,
    required String userId,
    required String displayName,
    ChatRole role = ChatRole.participant,
  }) async {
    final controller = _standaloneProvisioner;
    final joinInfo = _parseProvisionedJoinInfo(
      await controller.join(
        roomCode: roomCode,
        userId: userId,
        displayName: displayName,
        role: role,
      ),
    );
    Future<ChatJoinInfo> credentials() async => _parseProvisionedJoinInfo(
      await controller.provision(
        roomCode: joinInfo.roomCode,
        participantId: joinInfo.participantId,
        participantCredential: joinInfo.json['participantCredential']
            ?.toString(),
      ),
      expected: joinInfo,
    );
    return connect(joinInfo, credentialProvider: credentials);
  }

  Future<List<ChatRoomSummary>> listStandaloneRooms() =>
      _standaloneProvisioner.listRooms();

  ChatJoinInfo _parseProvisionedJoinInfo(
    ChatJoinInfo provisioned, {
    ChatJoinInfo? expected,
  }) {
    final providerId = provisioned.providerId.trim().toLowerCase();
    final factory = registry.require(providerId);
    final parsed = factory.parseJoinInfo(provisioned.json);
    final baseline = expected ?? provisioned;
    if (providerId != baseline.providerId.trim().toLowerCase() ||
        parsed.providerId.trim().toLowerCase() != providerId ||
        parsed.roomCode != baseline.roomCode ||
        parsed.participantId != baseline.participantId ||
        parsed.userId != baseline.userId ||
        parsed.role != baseline.role) {
      throw ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message:
            'Provisioned chat credentials changed the provider, room, '
            'participant, user, or role.',
        providerId: providerId,
      );
    }
    return parsed;
  }

  /// Connects directly using credentials provisioned by the host application.
  ///
  /// [credentialProvider] is optional for providers whose credentials do not
  /// expire while connected. When supplied, adapters may request a fresh
  /// [ChatJoinInfo] during reconnect without knowing how it was provisioned.
  Future<ChatRoomSession> connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) async {
    final factory = registry.require(joinInfo.providerId);
    final session = factory.createSession(joinInfo);
    try {
      await session.connect(joinInfo, credentialProvider: credentialProvider);
      return ChatRoomSession(
        roomCode: joinInfo.roomCode,
        participantId: joinInfo.participantId,
        userId: joinInfo.userId,
        role: joinInfo.role,
        session: session,
        moderation: provisioner is StandaloneChatModerationProvider
            ? (provisioner as StandaloneChatModerationProvider).moderationFor(
                joinInfo,
              )
            : backend is StandaloneChatModerationProvider
            ? (backend as StandaloneChatModerationProvider).moderationFor(
                joinInfo,
              )
            : null,
      );
    } catch (_) {
      await session.dispose();
      rethrow;
    }
  }

  Future<ChatRoomSession> connectRoom({
    required String roomCode,
    required String participantId,
    String? participantCredential,
    String? roomOwnerCredential,
  }) async {
    final customProvisioner = provisioner;
    Future<ChatJoinInfo> credentials() async {
      if (customProvisioner != null) {
        return customProvisioner.provision(
          roomCode: roomCode,
          participantId: participantId,
          participantCredential: participantCredential,
        );
      }
      final backend = this.backend;
      if (backend == null) {
        throw const ChatError(
          code: ChatErrorCode.unsupportedFeature,
          message:
              'connectRoom requires a ChatProvisioner or the optional HTTP '
              'backend convenience layer.',
        );
      }
      final response = await backend.issueToken(
        roomCode: roomCode,
        participantId: participantId,
        participantCredential: participantCredential,
        roomOwnerCredential: roomOwnerCredential,
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
    return connect(joinInfo, credentialProvider: credentials);
  }

  void dispose() => backend?.dispose();
}
