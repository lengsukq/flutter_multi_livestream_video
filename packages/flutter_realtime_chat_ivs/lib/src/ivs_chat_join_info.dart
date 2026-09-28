import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

class IvsChatJoinInfo extends ChatJoinInfo {
  const IvsChatJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.userId,
    required super.displayName,
    required super.role,
    required super.json,
    required this.roomArn,
    required this.token,
    required this.capabilities,
    required this.tokenExpirationTimeMs,
    required this.sessionExpirationTimeMs,
    required this.region,
  }) : super(providerId: providerIdValue);

  static const String providerIdValue = 'ivs-chat';

  final String roomArn;
  final String token;
  final List<String> capabilities;
  final int tokenExpirationTimeMs;
  final int sessionExpirationTimeMs;
  final String region;

  bool get canSendMessage => capabilities.contains('SEND_MESSAGE');
  bool get canDeleteMessage => capabilities.contains('DELETE_MESSAGE');
  bool get canDisconnectUser => capabilities.contains('DISCONNECT_USER');

  factory IvsChatJoinInfo.fromJson(Map<String, dynamic> json) {
    final provider = json['chatProvider']?.toString().trim().toLowerCase();
    if (provider != providerIdValue) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Chat credentials do not identify Amazon IVS Chat.',
        providerId: providerIdValue,
      );
    }
    final roomCode = _requireString(json, 'roomCode');
    final participantId = _requireString(json, 'participantId');
    final userId = _requireString(json, 'userId');
    final displayName = _requireString(json, 'displayName');
    final role = ChatRole.tryParse(json['role']);
    if (role == null) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'IVS Chat credentials are missing a valid role.',
        providerId: providerIdValue,
      );
    }
    final rawChat = json['chat'];
    if (rawChat is! Map) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'IVS Chat credentials are missing the chat block.',
        providerId: providerIdValue,
      );
    }
    final chat = Map<String, Object?>.from(rawChat);
    final roomArn = _requireString(chat, 'roomArn');
    final token = _requireString(chat, 'token');
    final region = _requireString(chat, 'region');
    final capabilities = (chat['capabilities'] is List)
        ? (chat['capabilities'] as List)
              .map((item) => item.toString().trim().toUpperCase())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final tokenExpirationTimeMs = _requireTimestamp(
      chat,
      'tokenExpirationTimeMs',
    );
    final sessionExpirationTimeMs = _requireTimestamp(
      chat,
      'sessionExpirationTimeMs',
    );
    if (!capabilities.contains('SEND_MESSAGE')) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'IVS Chat token must allow SEND_MESSAGE.',
        providerId: providerIdValue,
      );
    }
    if (role != ChatRole.host &&
        (capabilities.contains('DELETE_MESSAGE') ||
            capabilities.contains('DISCONNECT_USER'))) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message:
            'Only host chat credentials may include moderation capabilities.',
        providerId: providerIdValue,
      );
    }
    return IvsChatJoinInfo(
      roomCode: roomCode,
      participantId: participantId,
      userId: userId,
      displayName: displayName,
      role: role,
      json: json,
      roomArn: roomArn,
      token: token,
      capabilities: capabilities,
      tokenExpirationTimeMs: tokenExpirationTimeMs,
      sessionExpirationTimeMs: sessionExpirationTimeMs,
      region: region,
    );
  }

  static String _requireString(Map<dynamic, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'IVS Chat credentials are missing $key.',
        providerId: providerIdValue,
      );
    }
    return value;
  }

  static int _requireTimestamp(Map<dynamic, dynamic> json, String key) {
    final raw = json[key];
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) {
      throw ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'IVS Chat $key must be a positive Unix timestamp.',
        providerId: providerIdValue,
      );
    }
    return value;
  }
}
