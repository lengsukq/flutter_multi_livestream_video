import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

class TencentChatJoinInfo extends ChatJoinInfo {
  const TencentChatJoinInfo({
    required super.roomCode,
    required super.participantId,
    required super.userId,
    required super.displayName,
    required super.role,
    required super.json,
    required this.sdkAppId,
    required this.groupId,
    required this.providerUserId,
    required this.userSig,
    required this.capabilities,
    required this.userSigExpirationTimeMs,
  }) : super(providerId: providerIdValue);

  static const String providerIdValue = 'tencent-chat';

  final int sdkAppId;
  final String groupId;
  final String providerUserId;
  final String userSig;
  final List<String> capabilities;
  final int userSigExpirationTimeMs;

  bool get canSendMessage => capabilities.contains('SEND_MESSAGE');

  factory TencentChatJoinInfo.fromJson(Map<String, dynamic> json) {
    final provider = json['chatProvider']?.toString().trim().toLowerCase();
    if (provider != providerIdValue) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Chat credentials do not identify Tencent Cloud Chat.',
        providerId: providerIdValue,
      );
    }
    final role = ChatRole.tryParse(json['role']);
    if (role == null) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Tencent Chat credentials are missing a valid role.',
        providerId: providerIdValue,
      );
    }
    final rawChat = json['chat'];
    if (rawChat is! Map) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Tencent Chat credentials are missing the chat block.',
        providerId: providerIdValue,
      );
    }
    final chat = Map<String, Object?>.from(rawChat);
    final sdkAppId = _requirePositiveInt(chat, 'sdkAppId');
    final capabilities = _readCapabilities(chat);
    if (!capabilities.contains('SEND_MESSAGE')) {
      throw const ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Tencent Chat credentials must allow SEND_MESSAGE.',
        providerId: providerIdValue,
      );
    }
    return TencentChatJoinInfo(
      roomCode: _requireString(json, 'roomCode'),
      participantId: _requireString(json, 'participantId'),
      userId: _requireString(json, 'userId'),
      displayName: _requireString(json, 'displayName'),
      role: role,
      json: json,
      sdkAppId: sdkAppId,
      groupId: _requireString(chat, 'groupId'),
      providerUserId: _requireString(chat, 'providerUserId'),
      userSig: _requireString(chat, 'userSig'),
      capabilities: capabilities,
      userSigExpirationTimeMs: _requirePositiveInt(
        chat,
        'userSigExpirationTimeMs',
      ),
    );
  }

  static List<String> _readCapabilities(Map<dynamic, dynamic> json) {
    final raw = json['capabilities'];
    if (raw is! List) return const [];
    return raw
        .map((item) => item.toString().trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _requireString(Map<dynamic, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Tencent Chat credentials are missing $key.',
        providerId: providerIdValue,
      );
    }
    return value;
  }

  static int _requirePositiveInt(Map<dynamic, dynamic> json, String key) {
    final raw = json[key];
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) {
      throw ChatError(
        code: ChatErrorCode.invalidJoinInfo,
        message: 'Tencent Chat $key must be a positive integer.',
        providerId: providerIdValue,
      );
    }
    return value;
  }
}
