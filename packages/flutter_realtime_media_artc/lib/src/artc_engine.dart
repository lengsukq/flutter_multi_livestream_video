import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'artc_join_info.dart';

typedef ArtcEngineFactory = Future<ArtcEngine> Function();

/// Internal seam around the native ARTC engine. Fakes implement this for
/// offline adapter tests; app code normally uses [createNativeArtcEngine].
abstract interface class ArtcEngine {
  Future<void> join(ArtcJoinInfo info, ArtcEngineEvents events);
  Future<void> leave();
  Future<void> setMuted(bool muted);
  Future<void> setVideoEnabled(bool enabled);
  Future<void> switchCamera(MediaCameraPosition position);
  Future<void> sendMessage(String message, String topic);
  Future<void> dispose();
}

/// Typed callbacks delivered to the session from ARTC notifications.
class ArtcEngineEvents {
  const ArtcEngineEvents({
    this.onError,
    this.onParticipantJoined,
    this.onParticipantLeft,
    this.onRemoteVideoChanged,
    this.onRemoteAudioChanged,
    this.onMessage,
    this.onReconnecting,
    this.onRecovered,
    this.onAuthWillExpire,
  });

  final void Function(int code, String message)? onError;
  final void Function(String userId)? onParticipantJoined;
  final void Function(String userId)? onParticipantLeft;
  final void Function(String userId, bool available)? onRemoteVideoChanged;
  final void Function(String userId, bool available)? onRemoteAudioChanged;
  final void Function(String userId, String data)? onMessage;
  final void Function()? onReconnecting;
  final void Function()? onRecovered;
  final void Function()? onAuthWillExpire;
}

/// Creates the MethodChannel-backed engine on Android and iOS.
Future<ArtcEngine> createNativeArtcEngine() async => _NativeArtcEngine();

class _NativeArtcEngine implements ArtcEngine {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.oneplusdream.flutter_realtime_media_artc/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.oneplusdream.flutter_realtime_media_artc/events',
  );

  StreamSubscription<dynamic>? _eventSubscription;
  ArtcEngineEvents _handlers = const ArtcEngineEvents();

  @override
  Future<void> join(ArtcJoinInfo info, ArtcEngineEvents events) async {
    _handlers = events;
    _eventSubscription ??= _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) => _dispatch(Map<String, Object?>.from(event as Map)),
      onError: (Object error) => _handlers.onError?.call(-1, error.toString()),
    );
    await _invoke('join', {
      'appId': info.appId,
      'channelId': info.channelId,
      'userId': info.userId,
      'displayName': info.displayName,
      'authInfo': info.authInfo,
      'role': info.role.wireName,
      'roomMode': info.roomMode.name,
    });
  }

  @override
  Future<void> leave() => _invoke('leave');

  @override
  Future<void> setMuted(bool muted) => _invoke('setMuted', {'muted': muted});

  @override
  Future<void> setVideoEnabled(bool enabled) =>
      _invoke('setVideoEnabled', {'enabled': enabled});

  @override
  Future<void> switchCamera(MediaCameraPosition position) =>
      _invoke('switchCamera', {'position': position.name});

  @override
  Future<void> sendMessage(String message, String topic) =>
      _invoke('sendMessage', {'message': message, 'topic': topic});

  @override
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _invoke('dispose');
  }

  void _dispatch(Map<String, Object?> event) {
    final type = event['type']?.toString();
    final userId = event['userId']?.toString() ?? '';
    switch (type) {
      case 'participantJoined':
        if (userId.isNotEmpty) _handlers.onParticipantJoined?.call(userId);
        return;
      case 'participantLeft':
        if (userId.isNotEmpty) _handlers.onParticipantLeft?.call(userId);
        return;
      case 'videoChanged':
        if (userId.isNotEmpty) {
          _handlers.onRemoteVideoChanged?.call(
            userId,
            event['available'] == true,
          );
        }
        return;
      case 'audioChanged':
        if (userId.isNotEmpty) {
          _handlers.onRemoteAudioChanged?.call(
            userId,
            event['available'] == true,
          );
        }
        return;
      case 'message':
        if (userId.isNotEmpty) {
          _handlers.onMessage?.call(userId, event['data']?.toString() ?? '');
        }
        return;
      case 'reconnecting':
        _handlers.onReconnecting?.call();
        return;
      case 'recovered':
        _handlers.onRecovered?.call();
        return;
      case 'authWillExpire':
        _handlers.onAuthWillExpire?.call();
        return;
      case 'error':
        _handlers.onError?.call(
          (event['code'] as num?)?.toInt() ?? -1,
          event['message']?.toString() ?? 'ARTC SDK reported an error.',
        );
        return;
    }
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      throw MediaError(
        code: switch (error.code) {
          'permission_denied' => MediaErrorCode.permissionDenied,
          'invalid_state' => MediaErrorCode.invalidState,
          'unsupported_feature' => MediaErrorCode.unsupportedFeature,
          'invalid_join_info' => MediaErrorCode.invalidJoinInfo,
          _ => MediaErrorCode.nativeError,
        },
        message: error.message ?? 'ARTC native call failed (${error.code}).',
        details: error.details,
        providerId: ArtcJoinInfo.providerIdValue,
      );
    }
  }
}
