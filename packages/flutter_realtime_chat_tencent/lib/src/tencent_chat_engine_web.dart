import 'dart:async';
import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimSDKListener.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/tencent_cloud_chat_sdk_platform_interface.dart';
import 'package:tencent_cloud_chat_sdk/utils/const.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core_web.dart';

import 'tencent_chat_engine.dart';
import 'tencent_chat_join_info.dart';

Future<TencentChatEngine> createPlatformTencentChatEngine() async =>
    _TencentWebChatEngine();

class _TencentWebChatEngine implements TencentChatEngine {
  _TencentWebChatEngine()
    : _runtime = WebChatRuntime<TencentChatJoinInfo>(
        providerId: TencentChatJoinInfo.providerIdValue,
        driverFactory: _TencentChatWebDriver.new,
      );

  final WebChatRuntime<TencentChatJoinInfo> _runtime;

  @override
  Future<void> connect(
    TencentChatJoinInfo info,
    TencentChatEngineEvents events, {
    TencentChatTokenProvider? tokenProvider,
  }) => _runtime.connect(
    info,
    WebChatDriverEvents(
      onConnecting: events.onConnecting,
      onConnected: events.onConnected,
      onDisconnected: events.onDisconnected,
      onMessage: events.onMessage,
      onMessageDeleted: events.onMessageDeleted,
      onUserDisconnected: events.onUserDisconnected,
      onError: events.onError,
    ),
    tokenProvider: tokenProvider,
  );

  @override
  Future<void> sendMessage(String message) => _runtime.sendMessage(message);

  @override
  Future<void> deleteMessage(String messageId) =>
      _runtime.deleteMessage(messageId);

  @override
  Future<void> disconnectUser(String userId) => _runtime.disconnectUser(userId);

  @override
  Future<void> disconnect() => _runtime.disconnect();

  @override
  Future<void> dispose() => _runtime.dispose();
}

class _TencentChatWebDriver implements WebChatDriver<TencentChatJoinInfo> {
  WebChatDriverEvents _events = const WebChatDriverEvents();
  WebChatTokenProvider<TencentChatJoinInfo>? _tokenProvider;
  TencentChatJoinInfo? _info;
  V2TimAdvancedMsgListener? _messageListener;
  String? _messageListenerId;
  bool _initialized = false;
  bool _loggedIn = false;
  bool _joinedGroup = false;
  bool _connected = false;
  bool _disposed = false;
  bool _refreshing = false;

  TencentCloudChatSdkPlatform get _manager =>
      TencentCloudChatSdkPlatform.instance;

  @override
  Future<void> connect(
    TencentChatJoinInfo info,
    WebChatDriverEvents events, {
    WebChatTokenProvider<TencentChatJoinInfo>? tokenProvider,
  }) async {
    if (_disposed) throw StateError('Tencent Chat engine is disposed.');
    _events = events;
    _tokenProvider = tokenProvider;
    _info = info;
    _events.onConnecting?.call(false);

    final initResult = await _manager.initSDK(
      sdkAppID: info.sdkAppId,
      loglevel: LogLevelEnum.V2TIM_LOG_INFO.index,
      uiPlatform: TencentIMSDKCONST.Flutter,
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
    _initialized = true;

    final loginResult = await _manager.login(
      userID: info.providerUserId,
      userSig: info.userSig,
    );
    _requireSuccess(loginResult, 'log in to Tencent Chat');
    _loggedIn = true;

    _messageListener = V2TimAdvancedMsgListener(
      onRecvNewMessage: (message) => _emitMessage(message),
      onRecvMessageRevoked: (messageId) {
        final id = messageId.toString().trim();
        if (id.isNotEmpty) _events.onMessageDeleted?.call(id);
      },
    );
    _messageListenerId = await _manager.addAdvancedMsgListener(
      listener: _messageListener!,
    );

    final joinResult = await _manager.joinGroup(
      groupID: info.groupId,
      message: 'Join realtime media chat',
      groupType: 'Meeting',
    );
    // 10013 means the user is already in the group. Treat that as success.
    if (joinResult.code != 0 && joinResult.code != 10013) {
      _requireSuccess(joinResult, 'join Tencent Chat group');
    }
    _joinedGroup = true;
    _connected = true;
    _events.onConnected?.call();
  }

  @override
  Future<void> sendMessage(String message) async {
    final info = _requireInfo();
    final created = await _manager.createTextMessage(text: message);
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
    final result = await _manager.sendMessage(
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
    final info = _info;
    if (_joinedGroup && info != null) {
      try {
        await _manager.quitGroup(groupID: info.groupId);
      } catch (_) {
        // Group cleanup is best-effort; keep cleaning the rest of the session.
      }
      _joinedGroup = false;
    }
    final listenerId = _messageListenerId;
    if (listenerId != null) {
      try {
        await _manager.removeAdvancedMsgListener(uuid: listenerId);
      } catch (_) {
        // Continue cleanup if the listener was already removed.
      }
      _messageListenerId = null;
      _messageListener = null;
    }
    if (_loggedIn) {
      try {
        await _manager.logout();
      } catch (_) {
        // A failed join can leave the SDK partially logged in.
      }
      _loggedIn = false;
    }
    if (_connected || info != null) {
      _connected = false;
      _events.onDisconnected?.call('clientDisconnect');
    }
    _info = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    await disconnect();
    if (_initialized) {
      try {
        await _manager.unInitSDK();
      } catch (_) {
        // Best-effort SDK teardown; the Dart engine is disposed either way.
      }
      _initialized = false;
    }
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
    if (!_connected || _info == null) {
      throw StateError('Tencent Chat engine is not connected.');
    }
    return _info!;
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
