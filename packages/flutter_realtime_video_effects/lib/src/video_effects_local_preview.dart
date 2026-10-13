import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
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
  }) : _settings = const MediaLocalPreviewSettings(
         microphoneEnabled: false,
         cameraEnabled: false,
       ) {
    _failureSubscription = bridge.failures
        .where((failure) => failure.sourceId == _source?.id)
        .listen((failure) {
          if (_disposed) return;
          _settings = _settings.copyWith(cameraEnabled: false);
          _failures.add(
            RealtimeException(
              code: RealtimeErrorCode.providerError,
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
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        providerId: providerId,
        message: 'Viewers cannot start a local camera preview.',
      );
    }
    final effects = bridge ?? VideoEffectsBridge();
    return VideoEffectsLocalPreviewSession._(
      providerId: providerId,
      role: role,
      bridge: effects,
    );
  }

  @override
  final String providerId;

  @override
  final MediaRole role;

  final VideoEffectsBridge bridge;
  ProcessedVideoSource? _source;

  /// Available after the user has enabled the camera at least once.
  ProcessedVideoSource get source =>
      _source ??
      (throw const RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message:
            'Enable the preview camera before accessing its processed source.',
      ));
  Future<ProcessedVideoSource>? _creatingSource;
  MediaLocalPreviewSettings _settings;
  // Processing failures hide the broken track without changing the user's
  // camera choice. A successful effect change can restore that choice.
  bool _requestedCameraEnabled = false;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);
  final _failures = StreamController<RealtimeException>.broadcast();
  StreamSubscription<VideoEffectsFailure>? _failureSubscription;
  @override
  Stream<RealtimeException> get failures => _failures.stream;

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
  MediaVideoTrack? get cameraTrack => _settings.cameraEnabled && _source != null
      ? ProcessedVideoTrack(source: _source!)
      : null;

  @override
  MediaTrackRenderer get renderer => const ProcessedVideoTrackRenderer();

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
        .where(
          (device) =>
              device.id == (_source?.cameraDeviceId ?? _settings.camera?.id),
        )
        .firstOrNull;
    if (_settings.camera == null && selected != null) {
      _settings = _settings.copyWith(camera: selected);
    }
    return devices;
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _ensureActive();
    if (device.kind != MediaDeviceKind.camera) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message:
            'The SDK video-effects preview only owns camera device '
            'selection.',
        providerId: providerId,
      );
    }
    final source = _source;
    if (source != null) await bridge.selectCamera(source, device.id);
    _ensureActive();
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
    final source = enabled ? await _ensureSource() : _source;
    if (source != null) await bridge.setEnabled(source, enabled);
    _ensureActive();
    _requestedCameraEnabled = enabled;
    _settings = _settings.copyWith(cameraEnabled: enabled);
  }

  @override
  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) async {
    _ensureActive();
    if (!backgroundCapabilities.supports(effect)) {
      throw RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'The requested local background effect is not supported.',
        providerId: providerId,
      );
    }
    final source = _source;
    if (source != null) await bridge.setEffect(source, effect);
    if (source != null && _requestedCameraEnabled && !_settings.cameraEnabled) {
      await bridge.setEnabled(source, true);
    }
    _ensureActive();
    _settings = _settings.copyWith(
      backgroundEffect: effect,
      cameraEnabled: _requestedCameraEnabled,
    );
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('preview.subscription', () async {
      await _failureSubscription?.cancel();
    });
    await cleanup.run('preview.pendingSource', () async {
      try {
        await _creatingSource;
      } catch (_) {
        /* The enable caller receives the failure. */
      }
    });
    await cleanup.run('preview.source', () async {
      final source = _source;
      _source = null;
      if (source != null) await bridge.disposeSource(source);
    });
    await cleanup.run('preview.failures', _failures.close);
    cleanup.finish(domain: 'videoEffects');
  }

  void _ensureActive() {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The video-effects preview has already been disposed.',
        providerId: providerId,
      );
    }
  }

  Future<ProcessedVideoSource> _ensureSource() async {
    _ensureActive();
    if (_source != null) return _source!;
    return _creatingSource ??= _createSource().whenComplete(
      () => _creatingSource = null,
    );
  }

  Future<ProcessedVideoSource> _createSource() async {
    final source = await bridge.createSource(
      config: VideoEffectsSourceConfig(
        frameRate: 30,
        cameraDeviceId: _settings.camera?.id,
        effect: _settings.backgroundEffect,
      ),
    );
    if (_disposed) {
      await bridge.disposeSource(source);
      _ensureActive();
    }
    _source = source;
    return source;
  }
}
