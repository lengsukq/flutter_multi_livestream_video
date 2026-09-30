import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';

class VideoEffectsLocalPreviewSession
    implements
        MediaLocalPreviewSession,
        MediaBackgroundEffectsController,
        MediaLocalPreviewFailureEvents {
  VideoEffectsLocalPreviewSession._({
    required this.providerId,
    required this.role,
    required this.bridge,
    required this.source,
  }) : _settings = const MediaLocalPreviewSettings(
         microphoneEnabled: false,
         cameraEnabled: true,
       ) {
    _failureSubscription = bridge.failures
        .where((failure) => failure.sourceId == source.id)
        .listen((failure) {
          if (_disposed) return;
          _settings = _settings.copyWith(cameraEnabled: false);
          _failures.add(
            MediaError(
              code: MediaErrorCode.nativeError,
              providerId: providerId,
              message: failure.message,
            ),
          );
        });
  }

  static Future<VideoEffectsLocalPreviewSession> create({
    required String providerId,
    required MediaRole role,
    VideoEffectsBridge? bridge,
  }) async {
    if (role == MediaRole.viewer) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        providerId: providerId,
        message: 'Viewers cannot start a local camera preview.',
      );
    }
    final effects = bridge ?? VideoEffectsBridge();
    final source = await effects.createSource(
      config: const VideoEffectsSourceConfig(frameRate: 30),
    );
    return VideoEffectsLocalPreviewSession._(
      providerId: providerId,
      role: role,
      bridge: effects,
      source: source,
    );
  }

  @override
  final String providerId;

  @override
  final MediaRole role;

  final VideoEffectsBridge bridge;
  final ProcessedVideoSource source;
  MediaLocalPreviewSettings _settings;
  // Processing failures hide the broken track without changing the user's
  // camera choice. A successful effect change can restore that choice.
  bool _requestedCameraEnabled = true;
  bool _disposed = false;
  final _failures = StreamController<MediaError>.broadcast();
  StreamSubscription<VideoEffectsFailure>? _failureSubscription;
  @override
  Stream<MediaError> get failures => _failures.stream;

  @override
  MediaCapabilities get capabilities => const MediaCapabilities(
    canPublishAudio: true,
    canPublishVideo: true,
    canBlurBackground: true,
    canReplaceBackgroundImage: true,
    canEnumerateCameras: true,
    canSelectCamera: true,
  );

  @override
  MediaVideoTrack? get cameraTrack =>
      _settings.cameraEnabled ? ProcessedVideoTrack(source: source) : null;

  @override
  MediaTrackRenderer get renderer => const VideoEffectsTrackRenderer();

  @override
  MediaLocalPreviewSettings get settings => _settings;

  @override
  MediaBackgroundCapabilities get backgroundCapabilities =>
      const MediaBackgroundCapabilities(canBlur: true, canReplaceImage: true);

  @override
  MediaBackgroundEffect get backgroundEffect => _settings.backgroundEffect;

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    _ensureActive();
    final requested = kinds ?? MediaDeviceKind.values.toSet();
    if (!requested.contains(MediaDeviceKind.camera)) return const [];
    final cameras = await bridge.listCameras();
    final devices = cameras
        .map(
          (camera) => MediaDevice(
            id: camera.id,
            label: camera.label,
            kind: MediaDeviceKind.camera,
          ),
        )
        .toList(growable: false);
    final selected = devices
        .where((device) => device.id == source.cameraDeviceId)
        .firstOrNull;
    if (_settings.camera == null && selected != null)
      _settings = _settings.copyWith(camera: selected);
    return devices;
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _ensureActive();
    if (device.kind != MediaDeviceKind.camera) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message:
            'The SDK video-effects preview only owns camera device '
            'selection.',
        providerId: providerId,
      );
    }
    await bridge.selectCamera(source, device.id);
    _settings = _settings.copyWith(camera: device);
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _ensureActive();
    // Microphone permission/checking is handled by the normal Pre-Join
    // diagnostics. The effects bridge intentionally owns video only.
    _settings = _settings.copyWith(microphoneEnabled: enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _ensureActive();
    await bridge.setEnabled(source, enabled);
    _requestedCameraEnabled = enabled;
    _settings = _settings.copyWith(cameraEnabled: enabled);
  }

  @override
  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) async {
    _ensureActive();
    if (!backgroundCapabilities.supports(effect)) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'The requested local background effect is not supported.',
        providerId: providerId,
      );
    }
    await bridge.setEffect(source, effect);
    if (_requestedCameraEnabled && !_settings.cameraEnabled) {
      await bridge.setEnabled(source, true);
    }
    _settings = _settings.copyWith(
      backgroundEffect: effect,
      cameraEnabled: _requestedCameraEnabled,
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _failureSubscription?.cancel();
    try {
      await bridge.disposeSource(source);
    } finally {
      await _failures.close();
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The video-effects preview has already been disposed.',
        providerId: providerId,
      );
    }
  }
}
