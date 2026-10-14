import 'dart:async';
import 'standalone_chat_profile_provisioner.dart';

import 'package:http/http.dart' as http;

import '../model/chat_error.dart';
import '../model/chat_management_capability.dart';
import '../model/chat_role.dart';
import '../model/chat_room_context.dart';
import '../session/chat_join_info.dart';
import '../session/chat_moderation.dart';
import 'chat_backend_config.dart';
import 'chat_provisioner.dart';

const chatBackendContractHeader = 'X-Realtime-Chat-Contract';
const chatBackendContractVersion = 1;

class ChatBackendJoinResponse {
  const ChatBackendJoinResponse({
    required this.providerId,
    required this.roomCode,
    required this.json,
  });

  final String providerId;
  final String roomCode;
  final Map<String, dynamic> json;
}

class HttpStandaloneChatProvisioner
    implements
        StandaloneChatProfileProvisioner,
        StandaloneChatModerationProvider {
  HttpStandaloneChatProvisioner(
    ChatBackendConfig config, {
    http.Client? httpClient,
  }) : _backend = ChatBackendClient(config, httpClient: httpClient);

  final ChatBackendClient _backend;

  @override
  Future<ChatJoinInfo> createWithProfile({
    required String userId,
    required String displayName,
    String? avatarUrl,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) => create(
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    role: role,
    roomCode: roomCode,
  );

  @override
  Future<ChatJoinInfo> joinWithProfile({
    required String roomCode,
    required String userId,
    required String displayName,
    String? avatarUrl,
    ChatRole role = ChatRole.participant,
  }) => join(
    roomCode: roomCode,
    userId: userId,
    displayName: displayName,
    avatarUrl: avatarUrl,
    role: role,
  );

  @override
  Future<ChatJoinInfo> create({
    required String userId,
    required String displayName,
    String? avatarUrl,
    ChatRole role = ChatRole.host,
    String? roomCode,
  }) async {
    final created = await _backend._request(
      'POST',
      '/chat/rooms',
      body: {
        'userId': userId,
        'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (roomCode != null && roomCode.trim().isNotEmpty)
          'roomCode': roomCode.trim(),
      },
    );
    final providerId =
        created['chatProvider']?.toString().trim().toLowerCase() ?? '';
    if (providerId.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Standalone chat create response is missing chatProvider.',
      );
    }
    return ChatJoinInfo(
      providerId: providerId,
      roomCode: created['roomCode']?.toString() ?? '',
      participantId: created['participantId']?.toString() ?? userId,
      userId: created['userId']?.toString() ?? userId,
      displayName: created['displayName']?.toString() ?? displayName,
      role: ChatRole.tryParse(created['role']) ?? ChatRole.host,
      json: created,
      context: ChatRoomContext.standalone,
    );
  }

  @override
  Future<ChatJoinInfo> join({
    required String roomCode,
    required String userId,
    required String displayName,
    String? avatarUrl,
    ChatRole role = ChatRole.participant,
  }) async {
    final data = await _backend._request(
      'POST',
      '/chat/rooms/${Uri.encodeComponent(roomCode.trim())}/join',
      body: {
        'userId': userId,
        'displayName': displayName,
        'role': role.wireName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      },
    );
    final providerId =
        data['chatProvider']?.toString().trim().toLowerCase() ?? '';
    if (providerId.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Standalone chat response is missing chatProvider.',
      );
    }
    return ChatJoinInfo(
      providerId: providerId,
      roomCode: data['roomCode']?.toString() ?? roomCode,
      participantId: data['participantId']?.toString() ?? userId,
      userId: data['userId']?.toString() ?? userId,
      displayName: data['displayName']?.toString() ?? displayName,
      // The public join request is a hint, not authority. An older/malformed
      // backend omitting its assigned role must never promote the guest to
      // host just because the caller requested ChatRole.host.
      role: ChatRole.tryParse(data['role']) ?? ChatRole.participant,
      json: data,
      context: ChatRoomContext.standalone,
    );
  }

  @override
  Future<ChatJoinInfo> provision({
    required String roomCode,
    required String participantId,
    String? participantCredential,
  }) async {
    final data = await _backend._request(
      'POST',
      '/chat/rooms/${Uri.encodeComponent(roomCode.trim())}/credentials',
      body: {
        'participantId': participantId,
        if (participantCredential != null)
          'participantCredential': participantCredential,
      },
    );
    final providerId =
        data['chatProvider']?.toString().trim().toLowerCase() ?? '';
    return ChatJoinInfo(
      providerId: providerId,
      roomCode: data['roomCode']?.toString() ?? roomCode,
      participantId: data['participantId']?.toString() ?? participantId,
      userId: data['userId']?.toString() ?? participantId,
      displayName: data['displayName']?.toString() ?? participantId,
      role: ChatRole.tryParse(data['role']) ?? ChatRole.participant,
      json: data,
      context: ChatRoomContext.standalone,
    );
  }

  @override
  Future<List<ChatRoomSummary>> listRooms() async {
    final data = await _backend._request('GET', '/chat/rooms');
    final raw = data['rooms'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((item) {
          final map = Map<String, dynamic>.from(item);
          return ChatRoomSummary(
            roomCode: map['roomCode']?.toString() ?? '',
            providerId: map['chatProvider']?.toString() ?? '',
          );
        })
        .where((room) => room.roomCode.isNotEmpty)
        .toList(growable: false);
  }

  @override
  void dispose() => _backend.dispose();

  @override
  ChatModeration moderationFor(ChatJoinInfo joinInfo) =>
      _HttpStandaloneChatModeration(_backend, joinInfo);
}

class _HttpStandaloneChatModeration
    implements
        ChatModeration,
        ChatModerationCapabilitySource,
        ChatModerationStateSync {
  const _HttpStandaloneChatModeration(this.backend, this.joinInfo);
  final ChatBackendClient backend;
  final ChatJoinInfo joinInfo;

  Map<String, Object?> get _auth => {
    'requesterParticipantId': joinInfo.participantId,
    'participantCredential': joinInfo.json['participantCredential']?.toString(),
    'roomOwnerCredential': joinInfo.json['roomOwnerCredential']?.toString(),
  };

  bool _managementFlag(String key, {required bool fallback}) {
    final raw = joinInfo.json['management'];
    if (raw is! Map) return fallback;
    final value = raw[key];
    return value is bool ? value : fallback;
  }

  String get _roomPath => joinInfo.context == ChatRoomContext.standalone
      ? '/chat/rooms/${Uri.encodeComponent(joinInfo.roomCode)}'
      : '/rooms/${Uri.encodeComponent(joinInfo.roomCode)}/chat';

  @override
  ChatManagementCapabilities get moderationCapabilities =>
      ChatManagementCapabilities(
        listMembers: _managementFlag('listMembers', fallback: true)
            ? const ChatManagementCapability.backend()
            : const ChatManagementCapability.unsupported(),
        removeMember: _managementFlag('removeMember', fallback: false)
            ? const ChatManagementCapability.backend()
            : const ChatManagementCapability.unsupported(
                reason: 'The selected chat provider cannot remove members.',
              ),
        closeRoom: _managementFlag('closeRoom', fallback: true)
            ? const ChatManagementCapability.backend()
            : const ChatManagementCapability.unsupported(),
      );

  @override
  Future<List<ChatMember>> listMembers() async {
    final data = await backend._request(
      'POST',
      '$_roomPath/members',
      body: _auth,
    );
    final raw = data['members'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((value) {
          final item = Map<String, dynamic>.from(value);
          return ChatMember(
            userId: item['userId']?.toString() ?? '',
            displayName: item['displayName']?.toString() ?? '',
            avatarUrl: item['avatarUrl']?.toString(),
            role: ChatRole.tryParse(item['role']) ?? ChatRole.participant,
          );
        })
        .where((member) => member.userId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> removeMember(String userId) {
    if (!moderationCapabilities.removeMember.supported) {
      return _unsupported('server-enforced member removal');
    }
    return _post('remove', {'targetUserId': userId});
  }

  @override
  Future<void> syncRemovedMember(String userId) =>
      _post('remove', {'targetUserId': userId, 'providerEnforced': true});

  @override
  Future<void> closeRoom() {
    if (!moderationCapabilities.closeRoom.supported) {
      return _unsupported('close room');
    }
    return _post('close');
  }

  @override
  Future<void> banMember(String userId, {required bool banned}) =>
      _unsupported('ban/unban members');
  @override
  Future<void> muteMember(String userId, {required bool muted}) =>
      _unsupported('mute/unmute members');
  @override
  Future<void> recallMessage(String messageId) =>
      _unsupported('recall messages through the control plane');
  @override
  Future<void> changeMemberRole(String userId, ChatRole role) =>
      _unsupported('change member roles');

  Future<void> _post(
    String operation, [
    Map<String, Object?> extra = const {},
  ]) async {
    await backend._request(
      'POST',
      '$_roomPath/manage/$operation',
      body: {..._auth, ...extra},
    );
  }

  Future<void> _unsupported(String operation) => Future<void>.error(
    RealtimeException(
      code: RealtimeErrorCode.unsupportedFeature,
      message: 'The selected chat provider does not support $operation.',
      providerId: joinInfo.providerId,
    ),
  );
}

class ChatBackendClient implements StandaloneChatModerationProvider {
  ChatBackendClient(this.config, {http.Client? httpClient})
    : _executor = RealtimeHttpExecutor(client: httpClient);

  final ChatBackendConfig config;
  final RealtimeHttpExecutor _executor;
  bool _disposed = false;

  Future<ChatBackendJoinResponse> issueToken({
    required String roomCode,
    required String participantId,
    String? participantCredential,
    String? roomOwnerCredential,
  }) async {
    final code = _required(roomCode, 'roomCode');
    final data = await _request(
      'POST',
      '/rooms/${Uri.encodeComponent(code)}/chat/token',
      body: {
        'participantId': _required(participantId, 'participantId'),
        if (participantCredential != null &&
            participantCredential.trim().isNotEmpty)
          'participantCredential': participantCredential.trim(),
        if (roomOwnerCredential != null &&
            roomOwnerCredential.trim().isNotEmpty)
          'roomOwnerCredential': roomOwnerCredential.trim(),
      },
    );
    final providerId =
        data['chatProvider']?.toString().trim().toLowerCase() ??
        data['provider']?.toString().trim().toLowerCase() ??
        '';
    if (providerId.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'Backend chat response is missing chatProvider.',
      );
    }
    final returnedCode = data['roomCode']?.toString().trim() ?? '';
    return ChatBackendJoinResponse(
      providerId: providerId,
      roomCode: returnedCode.isEmpty ? code : returnedCode,
      json: {
        ...data,
        if (participantCredential != null &&
            participantCredential.trim().isNotEmpty)
          'participantCredential': participantCredential.trim(),
        if (roomOwnerCredential != null &&
            roomOwnerCredential.trim().isNotEmpty)
          'roomOwnerCredential': roomOwnerCredential.trim(),
        'context': ChatRoomContext.attached.wireName,
      },
    );
  }

  @override
  ChatModeration moderationFor(ChatJoinInfo joinInfo) =>
      _HttpStandaloneChatModeration(this, joinInfo);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    if (_disposed) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The chat backend client is closed.',
      );
    }
    final data = await _executor.request(
      method: method,
      uri: _uri(path),
      timeout: config.requestTimeout,
      domain: 'chat',
      headers: _headers,
      body: body,
    );
    final version = data['contractVersion'];
    if (version != null &&
        version.toString() != '$chatBackendContractVersion') {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'Unsupported chat backend contract version.',
        domain: 'chat',
      );
    }
    return data;
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      chatBackendContractHeader: '$chatBackendContractVersion',
    };
    final custom = await config.headersProvider?.call();
    if (custom != null) headers.addAll(custom);
    final token = (await config.tokenProvider?.call())?.trim();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) {
    final base = config.backendUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  String _required(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: '$name must not be empty.',
      );
    }
    return normalized;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _executor.close();
  }
}
