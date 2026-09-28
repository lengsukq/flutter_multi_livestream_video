import 'dart:async';
import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

import 'tencent_chat_engine.dart';
import 'tencent_chat_join_info.dart';

Future<TencentChatEngine> createDefaultTencentChatEngine() async =>
    _TencentSdkChatEngine();

class _TencentSdkChatEngine implements TencentChatEngine {
  TencentChatEngineEvents _events = const TencentChatEngineEvents();
  TencentChatTokenProvider? _tokenProvider;
  TencentChatJoinInfo? _info;
  V2TimAdvancedMsgListener? _messageListener;
  bool _connected = false;
  bool _disposed = false;
  bool _refreshing = false;

  dynamic get _manager => TencentImSDKPlugin.v2TIMManager;

  @override
  Future<void> connect(
    TencentChatJoinInfo info,
    TencentChatEngineEvents events, {
    TencentChatTokenProvider? tokenProvider,
  }) async {
    if (_disposed) throw StateError('Tencent Chat engine is disposed.');
    _events = events;
    _tokenProvider = tokenProvider;
    _info = info;
    _events.onConnecting?.call(false);

    final initResult = await _manager.initSDK(
      sdkAppID: info.sdkAppId,
      loglevel: LogLevelEnum.V2TIM_LOG_INFO,
      listener: V2TimSDKListener(
        onConnecting: () => _events.onConnecting?.call(true),
        onConnectSuccess: () {
          if (_connected) _events.onConnected?.call();
        },
        onConnectFailed: (code, message) =>
            _events.onError?.call(code, message),
        onKickedOffline: () {
          _connected = false;
          _events.onDisconnected?.call('kickedOffline');
        },
        onUserSigExpired: () => unawaited(_refreshToken()),
      ),
    );
    _requireSuccess(initResult, 'initialize Tencent Chat');

    final loginResult = await _manager.login(
      userID: info.providerUserId,
      userSig: info.userSig,
    );
    _requireSuccess(loginResult, 'log in to Tencent Chat');

    _messageListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) => _emitMessage(message),
      onRecvMessageRevoked: (messageId) {
        final id = messageId.toString().trim();
        if (id.isNotEmpty) _events.onMessageDeleted?.call(id);
      },
    );
    await _manager.getMessageManager().addAdvancedMsgListener(
      listener: _messageListener!,
    );

    final joinResult = await _manager.joinGroup(
      groupID: info.groupId,
      message: 'Join realtime media chat',
    );
    // 10013 means the user is already in the group. Treat that as success.
    if ((joinResult.code ?? -1) != 0 && (joinResult.code ?? -1) != 10013) {
      _requireSuccess(joinResult, 'join Tencent Chat group');
    }
    _connected = true;
    _events.onConnected?.call();
  }

  @override
  Future<void> sendMessage(String message) async {
    final info = _requireInfo();
    final messageManager = _manager.getMessageManager();
    final created = await messageManager.createTextMessage(text: message);
    _requireSuccess(created, 'create Tencent Chat message');
    final id = created.data?.id?.toString().trim() ?? '';
    if (id.isEmpty) {
      throw StateError('Tencent Chat returned an empty message creation id.');
    }
    final metadata = jsonEncode({
      'userId': info.userId,
      'displayName': info.displayName,
      'participantId': info.participantId,
    });
    final result = await messageManager.sendMessage(
      id: id,
      receiver: '',
      groupID: info.groupId,
      cloudCustomData: metadata,
    );
    _requireSuccess(result, 'send Tencent Chat message');
    final sent = result.data;
    if (sent != null) _emitMessage(sent);
  }

  @override
  Future<void> deleteMessage(String messageId) async =>
      throw UnsupportedError('Tencent Chat moderation is not enabled.');

  @override
  Future<void> disconnectUser(String userId) async =>
      throw UnsupportedError('Tencent Chat moderation is not enabled.');

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    final info = _info;
    if (info != null) {
      try {
        await _manager.quitGroup(groupID: info.groupId);
      } catch (_) {
        // Logging out below is authoritative for this client session.
      }
    }
    final listener = _messageListener;
    if (listener != null) {
      await _manager.getMessageManager().removeAdvancedMsgListener(
        listener: listener,
      );
      _messageListener = null;
    }
    try {
      await _manager.logout();
    } finally {
      _connected = false;
      _events.onDisconnected?.call('clientDisconnect');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    _disposed = true;
    _tokenProvider = null;
    _info = null;
  }

  Future<void> _refreshToken() async {
    if (_refreshing || _disposed) return;
    final provider = _tokenProvider;
    final current = _info;
    if (provider == null || current == null) {
      _events.onError?.call(401, 'Tencent Chat UserSig expired.');
      return;
    }
    _refreshing = true;
    try {
      _events.onConnecting?.call(true);
      final refreshed = await provider();
      _info = refreshed;
      final result = await _manager.login(
        userID: refreshed.providerUserId,
        userSig: refreshed.userSig,
      );
      _requireSuccess(result, 'refresh Tencent Chat UserSig');
      _events.onConnected?.call();
    } catch (error) {
      _events.onError?.call(401, error.toString());
    } finally {
      _refreshing = false;
    }
  }

  void _emitMessage(dynamic message) {
    final groupId = message.groupID?.toString().trim() ?? '';
    final info = _info;
    if (info == null || groupId != info.groupId) return;
    final id =
        message.msgID?.toString().trim() ?? message.id?.toString().trim() ?? '';
    if (id.isEmpty) return;
    final text = message.textElem?.text?.toString() ?? '';
    if (text.isEmpty) return;
    final metadata = _decodeMetadata(message.cloudCustomData?.toString());
    final timestamp = _timestampMs(message.timestamp);
    _events.onMessage?.call({
      'id': id,
      'userId': metadata['userId'] ?? message.sender?.toString() ?? '',
      'displayName':
          metadata['displayName'] ??
          message.nameCard?.toString() ??
          message.nickName?.toString() ??
          message.sender?.toString() ??
          '',
      'message': text,
      'timestampMs': timestamp,
      'attributes': <String, String>{
        'providerUserId': message.sender?.toString() ?? '',
        if (metadata['participantId'] != null)
          'participantId': metadata['participantId']!,
      },
    });
  }

  Map<String, String> _decodeMetadata(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } catch (_) {
      return const {};
    }
  }

  int _timestampMs(dynamic raw) {
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    return value < 100000000000 ? value * 1000 : value;
  }

  TencentChatJoinInfo _requireInfo() {
    final info = _info;
    if (!_connected || info == null) {
      throw StateError('Tencent Chat engine is not connected.');
    }
    return info;
  }

  void _requireSuccess(dynamic result, String operation) {
    final code = result?.code;
    if (code == 0) return;
    final desc = result?.desc?.toString().trim();
    throw StateError(
      '$operation failed (${code ?? 'unknown'}): '
      '${desc == null || desc.isEmpty ? 'unknown error' : desc}',
    );
  }
}
