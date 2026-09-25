import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';

import 'trtc_join_info.dart';

typedef TrtcEngineFactory = Future<TrtcEngine> Function();

/// Small internal boundary around the native SDK, also used by offline tests.
abstract interface class TrtcEngine {
  Future<int> enterRoom(TrtcJoinInfo joinInfo, TrtcEngineEvents events);

  Future<void> exitRoom();
  void startLocalAudio();
  void muteLocalAudio(bool muted);
  void muteLocalVideo(bool muted);
  void stopLocalPreview();
  void startLocalPreview(int viewId);
  void clearLocalView();
  void startRemoteView(String userId, int viewId);
  void stopRemoteView(String userId);
  int switchCamera(bool frontCamera);
  bool sendCustomCmdMsg(int commandId, String data);
  Future<void> dispose();
}

/// Provider events translated from the native TRTC listener.
class TrtcEngineEvents {
  const TrtcEngineEvents({
    this.onError,
    this.onRemoteUserEnterRoom,
    this.onRemoteUserLeaveRoom,
    this.onUserVideoAvailable,
    this.onUserAudioAvailable,
    this.onRecvCustomCmdMsg,
    this.onConnectionLost,
    this.onTryToReconnect,
    this.onConnectionRecovery,
    this.onStats,
  });

  final void Function(int code, String message)? onError;
  final void Function(String userId)? onRemoteUserEnterRoom;
  final void Function(String userId)? onRemoteUserLeaveRoom;
  final void Function(String userId, bool available)? onUserVideoAvailable;
  final void Function(String userId, bool available)? onUserAudioAvailable;
  final void Function(String userId, int commandId, String data)?
  onRecvCustomCmdMsg;
  final void Function()? onConnectionLost;
  final void Function()? onTryToReconnect;
  final void Function()? onConnectionRecovery;
  final void Function(MediaConnectionStats stats)? onStats;
}

/// Factory used by production sessions.
Future<TrtcEngine> createNativeTrtcEngine() async => _NativeTrtcEngine();

class _NativeTrtcEngine implements TrtcEngine {
  TRTCCloud? _cloud;
  TRTCCloudListener? _listener;
  Completer<int>? _enterCompleter;
  Completer<void>? _exitCompleter;
  TrtcEngineEvents _events = const TrtcEngineEvents();
  bool _enterRequested = false;
  bool _registered = false;
  MediaConnectionStats? _connectionStats;

  Future<TRTCCloud> _getCloud() async =>
      _cloud ??= await TRTCCloud.sharedInstance();

  TRTCCloudListener _createListener() => TRTCCloudListener(
    onEnterRoom: (result) {
      final completer = _enterCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(result);
      }
    },
    onExitRoom: (_) {
      final completer = _exitCompleter;
      if (completer != null && !completer.isCompleted) completer.complete();
    },
    onError: (code, message) => _events.onError?.call(code, message),
    onRemoteUserEnterRoom: (userId) =>
        _events.onRemoteUserEnterRoom?.call(userId),
    onRemoteUserLeaveRoom: (userId, _) =>
        _events.onRemoteUserLeaveRoom?.call(userId),
    onUserVideoAvailable: (userId, available) =>
        _events.onUserVideoAvailable?.call(userId, available),
    onUserAudioAvailable: (userId, available) =>
        _events.onUserAudioAvailable?.call(userId, available),
    onRecvCustomCmdMsg: (userId, commandId, _, data) =>
        _events.onRecvCustomCmdMsg?.call(userId, commandId, data),
    onConnectionLost: () => _events.onConnectionLost?.call(),
    onTryToReconnect: () => _events.onTryToReconnect?.call(),
    onConnectionRecovery: () => _events.onConnectionRecovery?.call(),
    onNetworkQuality: (localInfo, _) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final quality = _mapQuality(localInfo.quality);
      final next = (_connectionStats ?? MediaConnectionStats(timestampMs: now))
          .copyWith(
            timestampMs: now,
            upstreamQuality: quality,
            downstreamQuality: quality,
          );
      _connectionStats = next;
      _events.onStats?.call(next);
    },
    onStatistics: (statistics) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final uploadKbps = statistics.localStatisticsArray?.fold<int>(
        0,
        (sum, value) =>
            sum +
            (value.audioBitrate > 0 ? value.audioBitrate : 0) +
            (value.videoBitrate > 0 ? value.videoBitrate : 0),
      );
      final downloadKbps = statistics.remoteStatisticsArray?.fold<int>(
        0,
        (sum, value) =>
            sum +
            (value.audioBitrate > 0 ? value.audioBitrate : 0) +
            (value.videoBitrate > 0 ? value.videoBitrate : 0),
      );
      final next = (_connectionStats ?? MediaConnectionStats(timestampMs: now))
          .copyWith(
            timestampMs: now,
            rttMs: statistics.rtt >= 0 ? statistics.rtt : null,
            uplinkPacketLossPercent: statistics.upLoss >= 0
                ? statistics.upLoss.toDouble()
                : null,
            downlinkPacketLossPercent: statistics.downLoss >= 0
                ? statistics.downLoss.toDouble()
                : null,
            uploadKbps: uploadKbps,
            downloadKbps: downloadKbps,
          );
      _connectionStats = next;
      _events.onStats?.call(next);
    },
  );

  MediaNetworkQuality _mapQuality(TRTCQuality quality) => switch (quality) {
    TRTCQuality.excellent => MediaNetworkQuality.excellent,
    TRTCQuality.good => MediaNetworkQuality.good,
    TRTCQuality.poor => MediaNetworkQuality.fair,
    TRTCQuality.bad => MediaNetworkQuality.poor,
    TRTCQuality.vBad => MediaNetworkQuality.bad,
    TRTCQuality.down => MediaNetworkQuality.down,
    _ => MediaNetworkQuality.unknown,
  };

  @override
  Future<int> enterRoom(TrtcJoinInfo joinInfo, TrtcEngineEvents events) async {
    final cloud = await _getCloud();
    _events = events;
    _listener ??= _createListener();
    if (!_registered) {
      cloud.registerListener(_listener!);
      _registered = true;
    }
    cloud.setDefaultStreamRecvMode(true, true);
    final completer = Completer<int>();
    _enterCompleter = completer;
    _enterRequested = true;
    cloud.enterRoom(
      TRTCParams(
        sdkAppId: joinInfo.sdkAppId,
        userId: joinInfo.userId,
        userSig: joinInfo.userSig,
        roomId: 0,
        strRoomId: joinInfo.strRoomId,
        privateMapKey: joinInfo.privateMapKey,
        role: joinInfo.role == MediaRole.viewer
            ? TRTCRoleType.audience
            : TRTCRoleType.anchor,
      ),
      joinInfo.scene == TrtcRoomScene.videoCall
          ? TRTCAppScene.videoCall
          : TRTCAppScene.live,
    );
    try {
      return await completer.future.timeout(const Duration(seconds: 25));
    } finally {
      _enterCompleter = null;
    }
  }

  @override
  Future<void> exitRoom() async {
    final cloud = _cloud;
    if (cloud == null || !_enterRequested) return;
    final completer = Completer<void>();
    _exitCompleter = completer;
    try {
      cloud.exitRoom();
      await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Permit cleanup and re-entry even when the SDK misses the exit callback.
    } finally {
      _enterRequested = false;
      _exitCompleter = null;
    }
  }

  @override
  void startLocalAudio() =>
      _cloud!.startLocalAudio(TRTCAudioQuality.defaultMode);

  @override
  void muteLocalAudio(bool muted) => _cloud!.muteLocalAudio(muted);

  @override
  void muteLocalVideo(bool muted) =>
      _cloud!.muteLocalVideo(TRTCVideoStreamType.big, muted);

  @override
  void stopLocalPreview() => _cloud!.stopLocalPreview();

  @override
  void startLocalPreview(int viewId) => _cloud!.startLocalPreview(true, viewId);

  @override
  void clearLocalView() => _cloud?.updateLocalView(null);

  @override
  void startRemoteView(String userId, int viewId) =>
      _cloud!.startRemoteView(userId, TRTCVideoStreamType.big, viewId);

  @override
  void stopRemoteView(String userId) =>
      _cloud?.stopRemoteView(userId, TRTCVideoStreamType.big);

  @override
  int switchCamera(bool frontCamera) =>
      _cloud!.getDeviceManager().switchCamera(frontCamera);

  @override
  bool sendCustomCmdMsg(int commandId, String data) =>
      _cloud!.sendCustomCmdMsg(commandId, data, true, true);

  @override
  Future<void> dispose() async {
    await exitRoom();
    final cloud = _cloud;
    final listener = _listener;
    if (cloud != null && listener != null && _registered) {
      cloud.unRegisterListener(listener);
    }
    _cloud = null;
    _listener = null;
    _registered = false;
    if (cloud != null) TRTCCloud.destroySharedInstance();
  }
}
