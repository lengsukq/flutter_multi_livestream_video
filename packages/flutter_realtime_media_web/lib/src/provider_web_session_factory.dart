import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:web/web.dart' as web;

import 'provider_web_bridge.dart';
import 'provider_web_profile.dart';
import 'provider_web_track.dart';
import 'provider_web_track_renderer.dart';

class ProviderWebJoinInfo extends MediaJoinInfo {
  ProviderWebJoinInfo({
    required super.providerId,
    required super.roomCode,
    required super.participantId,
    required super.role,
    required super.displayName,
    required Map<String, Object?> backendPayload,
  }) : super(payload: backendPayload);
}

/// Browser implementation backed by the provider's official JavaScript SDK.
class ProviderWebSessionFactory
    implements
        MediaSessionFactory,
        MediaBackgroundCapabilitiesProvider,
        MediaLocalPreviewFactory {
  ProviderWebSessionFactory(this.providerId)
    : profile = ProviderWebProfile.forProvider(providerId);

  @override
  final String providerId;
  final ProviderWebProfile profile;

  @override
  Set<MediaRole> get supportedRoles => profile.supportedRoles;

  @override
  MediaBackgroundCapabilities backgroundCapabilitiesFor(MediaRole role) {
    if (role == MediaRole.viewer ||
        (!profile.canBlurBackground && !profile.canReplaceBackgroundImage) ||
        !_browserSupportsVideoEffects) {
      return const MediaBackgroundCapabilities.none();
    }
    return MediaBackgroundCapabilities(
      canBlur: profile.canBlurBackground,
      canReplaceImage: profile.canReplaceBackgroundImage,
    );
  }

  @override
  ProviderWebJoinInfo parseJoinInfo(Map<String, dynamic> json) {
    final actualProvider = json['provider']?.toString().trim().toLowerCase();
    if (actualProvider != null &&
        actualProvider.isNotEmpty &&
        actualProvider != providerId) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message:
            'Expected $providerId join information, got "$actualProvider".',
        providerId: providerId,
      );
    }
    final roomCode = MediaJoinInfo.requireStringIn(
      json,
      'roomCode',
      providerId: providerId,
    );
    final participantId = _participantIdFromPayload(json);
    final role = MediaRole.tryParse(json['role']) ?? MediaRole.participant;
    if (!supportedRoles.contains(role)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: '$providerId does not support the ${role.wireName} role.',
        providerId: providerId,
      );
    }
    return ProviderWebJoinInfo(
      providerId: providerId,
      roomCode: roomCode,
      participantId: participantId,
      role: role,
      displayName: _displayNameFromPayload(json),
      backendPayload: Map<String, Object?>.from(json),
    );
  }

  String _participantIdFromPayload(Map<String, dynamic> json) {
    final supplied = json['participantId']?.toString().trim();
    if (supplied != null && supplied.isNotEmpty) return supplied;
    if (profile.usesChimeAttendeePayload) {
      final attendee = json['attendee'] ?? json['Attendee'];
      if (attendee is Map) {
        final id = (attendee['AttendeeId'] ?? attendee['attendeeId'])
            ?.toString()
            .trim();
        if (id != null && id.isNotEmpty) return id;
      }
    }
    throw MediaError(
      code: MediaErrorCode.invalidJoinInfo,
      message: 'Join information is missing participantId.',
      providerId: providerId,
    );
  }

  String _displayNameFromPayload(Map<String, dynamic> json) {
    final displayName = json['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final nickname = json['nickname']?.toString().trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    if (profile.usesChimeAttendeePayload) {
      final attendee = json['attendee'] ?? json['Attendee'];
      if (attendee is Map) {
        return (attendee['ExternalUserId'] ?? attendee['externalUserId'])
                ?.toString()
                .trim() ??
            '';
      }
    }
    return '';
  }

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo is! ProviderWebJoinInfo ||
        joinInfo.providerId != providerId ||
        !supportedRoles.contains(joinInfo.role)) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'The join information does not match the $providerId adapter.',
        providerId: providerId,
      );
    }
    final sessionId =
        '${providerId}_${DateTime.now().microsecondsSinceEpoch}_'
        '${_nextSessionId++}';
    final capabilities = _capabilitiesFor(profile, joinInfo.role);
    return switch (joinInfo.role) {
      MediaRole.participant => ProviderWebParticipantSession(
        providerId: providerId,
        role: joinInfo.role,
        sessionId: sessionId,
        joinPayload: joinInfo.payload,
        capabilities: capabilities,
      ),
      MediaRole.host => ProviderWebBroadcastHostSession(
        providerId: providerId,
        role: joinInfo.role,
        sessionId: sessionId,
        joinPayload: joinInfo.payload,
        capabilities: capabilities,
      ),
      MediaRole.viewer => ProviderWebBroadcastViewerSession(
        providerId: providerId,
        role: joinInfo.role,
        sessionId: sessionId,
        joinPayload: joinInfo.payload,
        capabilities: capabilities,
      ),
    };
  }

  @override
  Future<MediaLocalPreviewSession> createLocalPreview({
    required MediaRole role,
  }) async {
    if (role == MediaRole.viewer) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: '$providerId viewers do not publish local camera video.',
        providerId: providerId,
      );
    }
    final previewId =
        'preview_${providerId}_${DateTime.now().microsecondsSinceEpoch}_'
        '${_nextPreviewId++}';
    final capabilities = _capabilitiesFor(profile, role);
    await ProviderWebBridge.createLocalPreview(
      providerId: providerId,
      previewId: previewId,
      settings: {
        'role': role.wireName,
        'cameraEnabled': true,
        'microphoneEnabled': false,
        'backgroundEffect': {
          'type': MediaBackgroundEffectType.none.name,
          'blurStrength': MediaBackgroundBlurStrength.medium.name,
        },
      },
    );
    return ProviderWebLocalPreviewSession(
      providerId: providerId,
      role: role,
      previewId: previewId,
      capabilities: capabilities,
    );
  }
}

int _nextSessionId = 0;
int _nextPreviewId = 0;

class ProviderWebLocalPreviewSession
    implements MediaLocalPreviewSession, MediaBackgroundEffectsController {
  ProviderWebLocalPreviewSession({
    required this.providerId,
    required this.role,
    required this.previewId,
    required this.capabilities,
  }) : _settings = const MediaLocalPreviewSettings(
         microphoneEnabled: false,
         cameraEnabled: true,
       ),
       _cameraTrack = ProviderWebVideoTrack(
         providerId: providerId,
         sessionId: previewId,
         id: 'preview:video:$previewId',
         participantId: 'preview:$previewId',
         isLocal: true,
         isScreenShare: false,
       );

  @override
  final String providerId;

  @override
  final MediaRole role;

  final String previewId;

  @override
  final MediaCapabilities capabilities;

  MediaLocalPreviewSettings _settings;
  final ProviderWebVideoTrack _cameraTrack;
  bool _disposed = false;

  @override
  MediaVideoTrack get cameraTrack => _cameraTrack;

  @override
  MediaTrackRenderer get renderer => const ProviderWebTrackRenderer();

  @override
  MediaLocalPreviewSettings get settings => _settings;

  @override
  MediaBackgroundCapabilities get backgroundCapabilities =>
      MediaBackgroundCapabilities(
        canBlur: capabilities.canBlurBackground,
        canReplaceImage: capabilities.canReplaceBackgroundImage,
      );

  @override
  MediaBackgroundEffect get backgroundEffect => _settings.backgroundEffect;

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    _ensureNotDisposed();
    final requested = kinds ?? MediaDeviceKind.values.toSet();
    final values = await ProviderWebBridge.listDevices(providerId, previewId);
    return values
        .map(_previewMediaDeviceFromJson)
        .where((device) => requested.contains(device.kind))
        .toList(growable: false);
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _ensureNotDisposed();
    await ProviderWebBridge.selectDevice(providerId, previewId, {
      'id': device.id,
      'label': device.label,
      'kind': device.kind.name,
    });
    _settings = _settings.copyWith(
      microphone: device.kind == MediaDeviceKind.microphone
          ? device
          : _settings.microphone,
      camera: device.kind == MediaDeviceKind.camera ? device : _settings.camera,
      audioOutput: device.kind == MediaDeviceKind.audioOutput
          ? device
          : _settings.audioOutput,
    );
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _ensureNotDisposed();
    await ProviderWebBridge.command(providerId, previewId, 'setMuted', {
      'muted': !enabled,
    });
    _settings = _settings.copyWith(microphoneEnabled: enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _ensureNotDisposed();
    await ProviderWebBridge.command(providerId, previewId, 'setVideoEnabled', {
      'enabled': enabled,
    });
    _settings = _settings.copyWith(cameraEnabled: enabled);
  }

  @override
  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) async {
    _ensureNotDisposed();
    if (!backgroundCapabilities.supports(effect)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            '$providerId does not support the requested SDK background '
            'effect in local preview.',
        providerId: providerId,
      );
    }
    await ProviderWebBridge.command(
      providerId,
      previewId,
      'setBackgroundEffect',
      {'type': effect.type.name, 'blurStrength': effect.blurStrength?.name},
    );
    _settings = _settings.copyWith(backgroundEffect: effect);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await ProviderWebBridge.dispose(providerId, previewId);
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The local preview has already been disposed.',
        providerId: providerId,
      );
    }
  }
}

MediaDevice _previewMediaDeviceFromJson(Map<String, Object?> json) {
  final kind = switch (json['kind']?.toString()) {
    'microphone' || 'audioinput' => MediaDeviceKind.microphone,
    'audioOutput' || 'audiooutput' => MediaDeviceKind.audioOutput,
    _ => MediaDeviceKind.camera,
  };
  return MediaDevice(
    id: json['id']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    kind: kind,
    groupId: json['groupId']?.toString(),
  );
}

MediaCapabilities _capabilitiesFor(ProviderWebProfile profile, MediaRole role) {
  final isViewer = role == MediaRole.viewer;
  final canScreenShare = !isViewer && _browserSupportsScreenShare;
  final canEnumerateDevices = _browserSupportsDeviceEnumeration;
  final canSelectAudioOutput =
      profile.supportsAudioOutputSelection &&
      _browserSupportsAudioOutputSelection;
  final canManageParticipants =
      role == MediaRole.host && profile.canManageParticipants;
  return MediaCapabilities(
    canPublishAudio: !isViewer,
    canPublishVideo: !isViewer,
    canBlurBackground:
        !isViewer && profile.canBlurBackground && _browserSupportsVideoEffects,
    canReplaceBackgroundImage:
        !isViewer &&
        profile.canReplaceBackgroundImage &&
        _browserSupportsVideoEffects,
    canSwitchCamera: !isViewer && profile.canSwitchCamera,
    canScreenShare: canScreenShare,
    canSendData: !isViewer && profile.canSendData,
    canReceiveData: profile.canReceiveData,
    canSubscribeVideo: true,
    canEnumerateAudioDevices: canEnumerateDevices,
    canEnumerateMicrophones: !isViewer && canEnumerateDevices,
    canEnumerateCameras: !isViewer && canEnumerateDevices,
    canSelectMicrophone: !isViewer && canEnumerateDevices,
    canSelectCamera: !isViewer && canEnumerateDevices,
    canSelectAudioOutput: canSelectAudioOutput,
    canReportNetworkStats: profile.canReportNetworkStats,
    canListParticipants: role == MediaRole.host,
    canRemoveParticipants:
        canManageParticipants && profile.canRemoveParticipants,
    canCloseRoom: canManageParticipants,
  );
}

bool get _browserSupportsDeviceEnumeration =>
    _hasBrowserMediaDeviceMethod('enumerateDevices');

bool get _browserSupportsScreenShare =>
    _hasBrowserMediaDeviceMethod('getDisplayMedia');

bool get _browserSupportsVideoEffects {
  try {
    if (!_hasBrowserMediaDeviceMethod('getUserMedia')) return false;
    final global = web.window as JSObject;
    final canvas = global.getProperty<JSAny?>('HTMLCanvasElement'.toJS);
    if (canvas == null) return false;
    final prototype = (canvas as JSObject).getProperty<JSAny?>(
      'prototype'.toJS,
    );
    return prototype != null &&
        (prototype as JSObject).hasProperty('captureStream'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

bool get _browserSupportsAudioOutputSelection {
  try {
    final global = web.window as JSObject;
    final mediaElement = global.getProperty<JSAny?>('HTMLMediaElement'.toJS);
    if (mediaElement == null) return false;
    final prototype = (mediaElement as JSObject).getProperty<JSAny?>(
      'prototype'.toJS,
    );
    return prototype != null &&
        (prototype as JSObject).hasProperty('setSinkId'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

bool _hasBrowserMediaDeviceMethod(String method) {
  try {
    final navigator = web.window.navigator as JSObject;
    final devices = navigator.getProperty<JSAny?>('mediaDevices'.toJS);
    return devices != null &&
        (devices as JSObject).hasProperty(method.toJS).toDart;
  } catch (_) {
    return false;
  }
}

class ProviderWebParticipantSession extends ProviderWebSessionBase
    implements
        InteractiveMediaSession,
        MediaBackgroundEffectsController,
        ProcessedVideoSink {
  ProviderWebParticipantSession({
    required super.providerId,
    required super.role,
    required super.sessionId,
    required super.joinPayload,
    required super.capabilities,
  });

  @override
  bool supportsProcessedVideoSource(ProcessedVideoSource source) =>
      supportsProcessedVideoSourceInternal(source);

  @override
  Future<void> attachProcessedVideoSource(ProcessedVideoSource source) =>
      attachProcessedVideoSourceInternal(source);

  @override
  Future<void> detachProcessedVideoSource() =>
      detachProcessedVideoSourceInternal();
}

class ProviderWebBroadcastHostSession extends ProviderWebSessionBase
    implements
        BroadcastHostSession,
        MediaBackgroundEffectsController,
        ProcessedVideoSink {
  ProviderWebBroadcastHostSession({
    required super.providerId,
    required super.role,
    required super.sessionId,
    required super.joinPayload,
    required super.capabilities,
  });

  @override
  bool supportsProcessedVideoSource(ProcessedVideoSource source) =>
      supportsProcessedVideoSourceInternal(source);

  @override
  Future<void> attachProcessedVideoSource(ProcessedVideoSource source) =>
      attachProcessedVideoSourceInternal(source);

  @override
  Future<void> detachProcessedVideoSource() =>
      detachProcessedVideoSourceInternal();
}

class ProviderWebBroadcastViewerSession extends ProviderWebSessionBase
    implements BroadcastViewerSession {
  ProviderWebBroadcastViewerSession({
    required super.providerId,
    required super.role,
    required super.sessionId,
    required super.joinPayload,
    required super.capabilities,
  });
}

abstract class ProviderWebSessionBase
    implements
        MediaSession,
        MediaDeviceController,
        MediaStatsProvider,
        MediaDataMessenger {
  ProviderWebSessionBase({
    required this.providerId,
    required this.role,
    required this.sessionId,
    required this.joinPayload,
    required MediaCapabilities capabilities,
  }) : _capabilities = capabilities,
       _snapshot = MediaSnapshot(role: role, capabilities: capabilities);

  @override
  final String providerId;

  @override
  final MediaRole role;

  final String sessionId;
  final Map<String, Object?> joinPayload;
  final MediaCapabilities _capabilities;

  MediaSnapshot _snapshot;
  MediaConnectionStats? _connectionStats;
  MediaBackgroundEffect _backgroundEffect = const MediaBackgroundEffect.none();
  ProcessedVideoSource? _processedVideoSource;
  bool _disposed = false;
  Future<void>? _joinFuture;
  Future<void>? _leaveFuture;
  Future<void>? _disposeFuture;

  final Map<String, ProviderWebVideoTrack> _tracks = {};
  final StreamController<MediaSessionState> _stateController =
      StreamController<MediaSessionState>.broadcast();
  final StreamController<MediaSnapshot> _snapshotController =
      StreamController<MediaSnapshot>.broadcast();
  final StreamController<MediaEvent> _eventController =
      StreamController<MediaEvent>.broadcast();
  final StreamController<MediaConnectionStats> _statsController =
      StreamController<MediaConnectionStats>.broadcast();

  @override
  MediaCapabilities get capabilities => _capabilities;

  @override
  MediaSessionState get state => _snapshot.state;

  @override
  MediaSnapshot get snapshot => _snapshot;

  @override
  Stream<MediaSessionState> get states => _stateController.stream;

  @override
  Stream<MediaSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<MediaEvent> get events => _eventController.stream;

  @override
  MediaConnectionStats? get connectionStats => _connectionStats;

  MediaBackgroundCapabilities get backgroundCapabilities =>
      MediaBackgroundCapabilities(
        canBlur: capabilities.canBlurBackground,
        canReplaceImage: capabilities.canReplaceBackgroundImage,
      );

  MediaBackgroundEffect get backgroundEffect => _backgroundEffect;

  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) async {
    _ensureActive();
    if (!capabilities.canBlurBackground &&
        effect.type == MediaBackgroundEffectType.none) {
      _backgroundEffect = effect;
      return;
    }
    if (!backgroundCapabilities.supports(effect)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            '$providerId does not support the requested SDK video effect '
            'for this role or browser.',
        providerId: providerId,
      );
    }
    if (_backgroundEffect == effect) return;
    final source = _processedVideoSource;
    if (source == null) {
      if (effect.type == MediaBackgroundEffectType.none) {
        _backgroundEffect = effect;
        return;
      }
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message:
            'Attach an SDK processed video source before applying '
            'background effects.',
        providerId: providerId,
      );
    }
    await _command('setProcessedVideoEffect', {
      'sourceId': source.id,
      ...effect.toJson(),
    });
    _backgroundEffect = effect;
  }

  bool supportsProcessedVideoSourceInternal(ProcessedVideoSource source) =>
      const {'agora', 'trtc', 'artc', 'chime', 'ivs'}.contains(providerId) &&
      role != MediaRole.viewer &&
      source.platform == VideoEffectsPlatform.web &&
      source.kind == ProcessedVideoSourceKind.mediaStreamTrack;

  Future<void> attachProcessedVideoSourceInternal(
    ProcessedVideoSource source,
  ) async {
    _ensureActive();
    if (!supportsProcessedVideoSourceInternal(source)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            '$providerId cannot publish the supplied SDK processed '
            'video source on Web.',
        providerId: providerId,
      );
    }
    await _command('attachProcessedVideoSource', {'sourceId': source.id});
    _processedVideoSource = source;
  }

  Future<void> detachProcessedVideoSourceInternal() async {
    if (_processedVideoSource == null) return;
    if (state == MediaSessionState.connected ||
        state == MediaSessionState.reconnecting) {
      await _command('detachProcessedVideoSource', const {});
    }
    _processedVideoSource = null;
    _backgroundEffect = const MediaBackgroundEffect.none();
  }

  @override
  Stream<MediaConnectionStats> get stats => _statsController.stream;

  @override
  Future<void> join(MediaJoinInfo joinInfo) {
    final current = _joinFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _join(joinInfo).whenComplete(() {
      if (identical(_joinFuture, future)) _joinFuture = null;
    });
    _joinFuture = future;
    return future;
  }

  Future<void> _join(MediaJoinInfo joinInfo) async {
    _ensureNotDisposed();
    if (joinInfo.providerId != providerId ||
        joinInfo.role != role ||
        joinInfo.roomCode.isEmpty ||
        joinInfo.participantId.isEmpty) {
      throw MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'Join information does not match this $providerId session.',
        providerId: providerId,
      );
    }
    if (state != MediaSessionState.idle &&
        state != MediaSessionState.ended &&
        state != MediaSessionState.failed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'This $providerId session is already active.',
        providerId: providerId,
      );
    }
    _setState(MediaSessionState.joining);
    try {
      ProviderWebBridge.registerHandler(sessionId, _onBridgeEvent);
      await ProviderWebBridge.create(
        providerId: providerId,
        sessionId: sessionId,
        joinPayload: joinInfo.payload,
      );
      _setState(MediaSessionState.connecting);
      await ProviderWebBridge.join(providerId, sessionId);
      if (state == MediaSessionState.connecting) {
        _setState(MediaSessionState.connected);
      }
      _updateSnapshot(_snapshot.copyWith(clearLastError: true));
    } catch (error) {
      final mapped = _mapError('Unable to join the $providerId room.', error);
      _setState(MediaSessionState.failed, error: mapped);
      _emit(MediaFailureEvent(mapped));
      throw mapped;
    }
  }

  @override
  Future<void> leave() {
    final current = _leaveFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _leave().whenComplete(() {
      if (identical(_leaveFuture, future)) _leaveFuture = null;
    });
    _leaveFuture = future;
    return future;
  }

  Future<void> _leave() async {
    if (_disposed ||
        state == MediaSessionState.ended ||
        state == MediaSessionState.idle) {
      return;
    }
    _setState(MediaSessionState.leaving);
    try {
      await ProviderWebBridge.leave(providerId, sessionId);
      _tracks.clear();
      _setState(MediaSessionState.ended);
      _updateSnapshot(
        _snapshot.copyWith(
          participants: const [],
          localMuted: true,
          localVideoEnabled: false,
          clearLocalParticipantId: true,
          clearContentShareTrack: true,
        ),
      );
    } catch (error) {
      final mapped = _mapError('Unable to leave the $providerId room.', error);
      _setState(MediaSessionState.failed, error: mapped);
      _emit(MediaFailureEvent(mapped));
      throw mapped;
    }
  }

  @override
  Future<void> dispose() {
    final current = _disposeFuture;
    if (current != null) return current;
    late final Future<void> future;
    future = _dispose().whenComplete(() {
      if (identical(_disposeFuture, future)) _disposeFuture = null;
    });
    _disposeFuture = future;
    return future;
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    if (state.isActive || state == MediaSessionState.connecting) {
      try {
        await leave();
      } catch (_) {}
    }
    await ProviderWebBridge.dispose(providerId, sessionId);
    _disposed = true;
    _setState(MediaSessionState.disposed);
    await _stateController.close();
    await _snapshotController.close();
    await _eventController.close();
    await _statsController.close();
  }

  Future<void> setMuted(bool muted) async {
    _ensureActive();
    _requireCapability(capabilities.canPublishAudio, 'microphone control');
    await _command('setMuted', {'muted': muted});
    _updateSnapshot(_snapshot.copyWith(localMuted: muted));
    _emit(MediaLocalMediaChanged(muted: muted));
  }

  Future<void> toggleMute() => setMuted(!_snapshot.localMuted);

  Future<void> setVideoEnabled(bool enabled) async {
    _ensureActive();
    _requireCapability(capabilities.canPublishVideo, 'camera control');
    await _command('setVideoEnabled', {'enabled': enabled});
    _updateSnapshot(_snapshot.copyWith(localVideoEnabled: enabled));
    _emit(MediaLocalMediaChanged(videoEnabled: enabled));
  }

  Future<void> setScreenShareEnabled(bool enabled) async {
    _ensureActive();
    _requireCapability(capabilities.canScreenShare, 'screen sharing');
    await _command('setScreenShareEnabled', {'enabled': enabled});
  }

  Future<void> switchCamera(MediaCameraPosition position) async {
    _ensureActive();
    _requireCapability(capabilities.canSwitchCamera, 'camera switching');
    await _command('switchCamera', {'position': position.name});
  }

  Future<List<MediaAudioDevice>> listAudioDevices() async {
    _ensureActive();
    _requireCapability(capabilities.canEnumerateAudioDevices, 'audio devices');
    final devices = await listMediaDevices(
      kinds: const {MediaDeviceKind.audioOutput},
    );
    return devices
        .map(
          (device) =>
              MediaAudioDevice.fromLabel(device.label).copyWithId(device.id),
        )
        .toList(growable: false);
  }

  Future<void> selectAudioDevice(MediaAudioDevice device) async {
    _ensureActive();
    _requireCapability(
      capabilities.canSelectAudioOutput,
      'audio output selection',
    );
    await _command('selectAudioOutput', {
      'id': device.id,
      'label': device.label,
    });
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    _ensureActive();
    _requireCapability(capabilities.canSendData, 'sending data messages');
    if (message.trim().isEmpty || topic.trim().isEmpty) {
      throw MediaError(
        code: MediaErrorCode.invalidArgument,
        message: 'Message and topic must not be empty.',
        providerId: providerId,
      );
    }
    await _command('sendMessage', {
      'message': message,
      'topic': topic,
      'lifetimeMs': 300000,
    });
  }

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    _ensureNotDisposed();
    _requireCapability(
      capabilities.canEnumerateMicrophones ||
          capabilities.canEnumerateCameras ||
          capabilities.canEnumerateAudioDevices,
      'device enumeration',
    );
    final requested = kinds ?? MediaDeviceKind.values.toSet();
    final values = await ProviderWebBridge.listDevices(providerId, sessionId);
    return values
        .map(_mediaDeviceFromJson)
        .where((device) => requested.contains(device.kind))
        .where(_deviceCanBeListed)
        .toList(growable: false);
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _ensureActive();
    final supported = switch (device.kind) {
      MediaDeviceKind.microphone => capabilities.canSelectMicrophone,
      MediaDeviceKind.camera => capabilities.canSelectCamera,
      MediaDeviceKind.audioOutput => capabilities.canSelectAudioOutput,
    };
    _requireCapability(supported, '${device.kind.name} selection');
    await ProviderWebBridge.selectDevice(providerId, sessionId, {
      'id': device.id,
      'label': device.label,
      'kind': device.kind.name,
    });
  }

  MediaDevice _mediaDeviceFromJson(Map<String, Object?> json) {
    final kindName = json['kind']?.toString();
    final kind = switch (kindName) {
      'microphone' || 'audioinput' => MediaDeviceKind.microphone,
      'camera' || 'videoinput' => MediaDeviceKind.camera,
      'audioOutput' || 'audiooutput' => MediaDeviceKind.audioOutput,
      _ => MediaDeviceKind.camera,
    };
    return MediaDevice(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      kind: kind,
      groupId: json['groupId']?.toString(),
    );
  }

  bool _deviceCanBeListed(MediaDevice device) => switch (device.kind) {
    MediaDeviceKind.microphone => capabilities.canEnumerateMicrophones,
    MediaDeviceKind.camera => capabilities.canEnumerateCameras,
    MediaDeviceKind.audioOutput => capabilities.canEnumerateAudioDevices,
  };

  void _onBridgeEvent(String eventSessionId, Map<String, dynamic> event) {
    if (_disposed || eventSessionId != sessionId) return;
    switch (event['type']?.toString()) {
      case 'state':
        final next = _stateFromString(event['state']?.toString());
        if (next != null) _setState(next, reason: event['reason']?.toString());
        break;
      case 'snapshot':
        _updateFromBridgeSnapshot(event);
        break;
      case 'stats':
        _updateStats(event);
        break;
      case 'message':
        if (event['throttled'] == true) break;
        final message = MediaMessage(
          participantId: event['participantId']?.toString() ?? '',
          displayName: event['displayName']?.toString() ?? '',
          message: event['message']?.toString() ?? '',
          topic: event['topic']?.toString() ?? 'chat',
          timestampMs:
              (event['timestampMs'] as num?)?.toInt() ??
              DateTime.now().millisecondsSinceEpoch,
          providerId: providerId,
        );
        _updateSnapshot(
          _snapshot.copyWith(messages: [..._snapshot.messages, message]),
        );
        _emit(MediaMessageReceived(message));
        break;
      case 'error':
        final error = MediaError(
          code: MediaErrorCode.nativeError,
          message: event['message']?.toString() ?? 'Browser media SDK error.',
          providerId: providerId,
        );
        _setState(MediaSessionState.failed, error: error);
        _emit(MediaFailureEvent(error));
        break;
    }
  }

  void _updateFromBridgeSnapshot(Map<String, dynamic> event) {
    final nextTracks = <String, ProviderWebVideoTrack>{};
    final rawTracks = event['tracks'];
    if (rawTracks is List) {
      for (final raw in rawTracks.whereType<Map>()) {
        final value = Map<String, Object?>.from(raw);
        final id = value['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        nextTracks[id] = ProviderWebVideoTrack(
          providerId: providerId,
          sessionId: sessionId,
          id: id,
          participantId: value['participantId']?.toString() ?? '',
          isLocal: value['isLocal'] == true,
          isScreenShare: value['isScreenShare'] == true,
          width: _asInt(value['width']) ?? 0,
          height: _asInt(value['height']) ?? 0,
        );
      }
    }
    final previousTracks = Map<String, ProviderWebVideoTrack>.from(_tracks);
    _tracks
      ..clear()
      ..addAll(nextTracks);

    final rawParticipants = event['participants'];
    final participants = <MediaParticipant>[];
    if (rawParticipants is List) {
      for (final raw in rawParticipants.whereType<Map>()) {
        final value = Map<String, Object?>.from(raw);
        final id = value['id']?.toString().trim() ?? '';
        if (id.isEmpty) continue;
        final trackId = value['videoTrackId']?.toString();
        final videoTrack = trackId == null ? null : nextTracks[trackId];
        participants.add(
          MediaParticipant(
            id: id,
            displayName:
                value['displayName']?.toString().trim().isNotEmpty == true
                ? value['displayName'].toString().trim()
                : id,
            isLocal: value['isLocal'] == true,
            isMuted: value['isMuted'] == true,
            isVideoEnabled:
                value['isVideoEnabled'] == true || videoTrack != null,
            isSpeaking: value['isSpeaking'] == true,
            videoTrack: videoTrack,
          ),
        );
      }
    }
    final localParticipantId = event['localParticipantId']?.toString();
    final contentShareTrack = nextTracks.values
        .where((track) => track.isScreenShare)
        .firstOrNull;
    final previousParticipants = {
      for (final item in _snapshot.participants) item.id: item,
    };
    final currentParticipants = {
      for (final item in participants) item.id: item,
    };
    for (final participant in participants) {
      final previous = previousParticipants[participant.id];
      if (previous == null) _emit(MediaParticipantJoined(participant));
      if (previous?.videoTrack == null && participant.videoTrack != null) {
        _emit(MediaTrackPublished(participant.videoTrack!));
      }
    }
    for (final participant in _snapshot.participants) {
      if (!currentParticipants.containsKey(participant.id)) {
        _emit(
          MediaParticipantLeft(
            participantId: participant.id,
            displayName: participant.displayName,
          ),
        );
      }
    }
    for (final track in previousTracks.values) {
      if (!nextTracks.containsKey(track.id)) {
        _emit(
          MediaTrackUnpublished(
            trackId: track.id,
            participantId: track.participantId,
            wasScreenShare: track.isScreenShare,
          ),
        );
      }
    }
    final localMuted = event['localMuted'];
    final localVideoEnabled = event['localVideoEnabled'];
    _updateSnapshot(
      _snapshot.copyWith(
        participants: participants,
        localParticipantId: localParticipantId,
        clearLocalParticipantId:
            localParticipantId == null || localParticipantId.isEmpty,
        localMuted: localMuted is bool ? localMuted : null,
        localVideoEnabled: localVideoEnabled is bool ? localVideoEnabled : null,
        contentShareTrack: contentShareTrack,
        clearContentShareTrack: contentShareTrack == null,
      ),
    );
  }

  void _updateStats(Map<String, dynamic> event) {
    if (!capabilities.canReportNetworkStats) return;
    final stats = MediaConnectionStats(
      timestampMs:
          _asInt(event['timestampMs']) ?? DateTime.now().millisecondsSinceEpoch,
      upstreamQuality: _quality(event['upstreamQuality']),
      downstreamQuality: _quality(event['downstreamQuality']),
      rttMs: _asInt(event['rttMs']),
      uplinkPacketLossPercent: _asDouble(event['uplinkPacketLossPercent']),
      downlinkPacketLossPercent: _asDouble(event['downlinkPacketLossPercent']),
      uploadKbps: _asInt(event['uploadKbps']),
      downloadKbps: _asInt(event['downloadKbps']),
      jitterMs: _asInt(event['jitterMs']),
    );
    _connectionStats = stats;
    if (!_statsController.isClosed) _statsController.add(stats);
    _emit(MediaNetworkStatsUpdated(stats));
  }

  void _setState(MediaSessionState next, {String? reason, MediaError? error}) {
    if (state == next) return;
    final previous = state;
    _updateSnapshot(
      _snapshot.copyWith(
        state: next,
        lastError: error,
        clearLastError: error == null && next != MediaSessionState.failed,
      ),
    );
    if (!_stateController.isClosed) _stateController.add(next);
    _emit(
      MediaConnectionStateChanged(
        previous: previous,
        current: next,
        reason: reason,
      ),
    );
  }

  void _updateSnapshot(MediaSnapshot value) {
    _snapshot = value;
    if (!_snapshotController.isClosed) _snapshotController.add(value);
  }

  void _emit(MediaEvent event) {
    if (!_eventController.isClosed) _eventController.add(event);
  }

  Future<void> _command(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    _ensureActive();
    final response = await _rawCommand(name, args);
    if (response.isNotEmpty) {
      try {
        final decoded = jsonDecode(response);
        if (decoded is Map && decoded['snapshot'] is Map) {
          _updateFromBridgeSnapshot(
            Map<String, dynamic>.from(decoded['snapshot'] as Map),
          );
        }
      } catch (_) {}
    }
  }

  Future<String> _rawCommand(String name, Map<String, Object?> args) async =>
      ProviderWebBridge.command(providerId, sessionId, name, args);

  void _ensureActive() {
    _ensureNotDisposed();
    if (!state.isActive) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message:
            'Cannot control $providerId media while the session is $state.',
        providerId: providerId,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed || state == MediaSessionState.disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'This $providerId session has been disposed.',
        providerId: providerId,
      );
    }
  }

  void _requireCapability(bool supported, String feature) {
    if (!supported) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            '$providerId $feature is not supported in this browser session.',
        providerId: providerId,
      );
    }
  }

  MediaError _mapError(String fallback, Object error) {
    if (error is MediaError) return error.withProvider(providerId);
    return MediaError(
      code: error.toString().toLowerCase().contains('permission')
          ? MediaErrorCode.permissionDenied
          : MediaErrorCode.nativeError,
      message: '$fallback ${error.toString()}',
      details: error,
      providerId: providerId,
    );
  }
}

MediaSessionState? _stateFromString(String? value) => switch (value) {
  'joining' => MediaSessionState.joining,
  'connecting' => MediaSessionState.connecting,
  'connected' => MediaSessionState.connected,
  'reconnecting' => MediaSessionState.reconnecting,
  'leaving' => MediaSessionState.leaving,
  'ended' => MediaSessionState.ended,
  'failed' => MediaSessionState.failed,
  _ => null,
};

MediaNetworkQuality _quality(Object? value) =>
    switch (value?.toString().toLowerCase()) {
      'excellent' || '1' => MediaNetworkQuality.excellent,
      'good' || '2' => MediaNetworkQuality.good,
      'fair' || '3' => MediaNetworkQuality.fair,
      'poor' || '4' => MediaNetworkQuality.poor,
      'bad' || '5' => MediaNetworkQuality.bad,
      'down' || '6' => MediaNetworkQuality.down,
      _ => MediaNetworkQuality.unknown,
    };

int? _asInt(Object? value) => value is int
    ? value
    : value is num
    ? value.toInt()
    : int.tryParse(value?.toString() ?? '');

double? _asDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

extension on MediaAudioDevice {
  MediaAudioDevice copyWithId(String? value) =>
      MediaAudioDevice(id: value, label: label, type: type);
}
