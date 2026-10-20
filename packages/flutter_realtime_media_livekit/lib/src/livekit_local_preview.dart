import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'livekit_media_track.dart';
import 'livekit_track_renderer.dart';

class LiveKitLocalPreviewSession
    implements MediaLocalPreviewSession, MediaLocalPreviewAudioLevels {
  LiveKitLocalPreviewSession._({
    required this.role,
    required this.capabilities,
    required lk.LocalVideoTrack? cameraTrack,
  }) : _cameraTrack = cameraTrack,
       _settings = MediaLocalPreviewSettings(
         cameraEnabled: cameraTrack != null,
       );

  static Future<LiveKitLocalPreviewSession> create({
    required MediaRole role,
  }) async {
    final canPublish = role != MediaRole.viewer;
    final capabilities = _previewCapabilities(canPublish);
    return LiveKitLocalPreviewSession._(
      role: role,
      capabilities: capabilities,
      cameraTrack: null,
    );
  }

  Future<void> _startAudioMeter(lk.LocalAudioTrack track) async {
    try {
      final meter = lk.createVisualizer(
        track,
        options: const lk.AudioVisualizerOptions(
          barCount: 16,
          centeredBands: false,
          smoothTransition: false,
        ),
      );
      final listener = meter.createListener();
      _audioVisualizer = meter;
      _audioListener = listener;
      listener.on<lk.AudioVisualizerEvent>((event) {
        if (_disposed || _microphoneLevels.isClosed) return;
        var peak = 0.0;
        for (final sample in event.event) {
          if (sample is num && sample.isFinite) {
            final amplitude = sample.toDouble();
            if (amplitude > peak) peak = amplitude;
          }
        }
        // SDK visualizer samples are normalized, but some native versions
        // report byte amplitudes instead. Both are based on captured audio.
        final normalized = peak > 1 ? peak / 255 : peak;
        _microphoneLevels.add(normalized.clamp(0.0, 1.0));
      });
      await meter.start();
    } catch (_) {
      // A missing native visualizer (older hosts) is not a capture failure.
      // No visualizer means an idle meter rather than a fabricated signal.
      await _stopAudioMeter();
    }
  }

  Future<void> _stopAudioMeter() async {
    final listener = _audioListener;
    final meter = _audioVisualizer;
    _audioListener = null;
    _audioVisualizer = null;
    try {
      await listener?.dispose();
    } catch (_) {
      // A visualizer shutdown failure must not leave microphone capture on.
    }
    if (meter != null) {
      try {
        await meter.stop();
      } catch (_) {
        // Best-effort visualizer cleanup; track.stop() still owns capture.
      }
      try {
        await meter.dispose();
      } catch (_) {
        // The preview's microphone track is stopped separately.
      }
    }
    if (!_disposed && !_microphoneLevels.isClosed) _microphoneLevels.add(0);
  }

  static MediaCapabilities _previewCapabilities(bool canPublish) {
    final desktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    final canSelectOutput =
        !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;
    return MediaCapabilities(
      canPublishAudio: canPublish,
      canPublishVideo: canPublish,
      canSwitchCamera: canPublish,
      canEnumerateAudioDevices: true,
      canEnumerateMicrophones: canPublish,
      canEnumerateCameras: canPublish,
      canSelectMicrophone: canPublish && (kIsWeb || desktop),
      canSelectCamera: canPublish,
      canSelectAudioOutput: canSelectOutput,
    );
  }

  static bool _isPermissionFailure(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('permission') ||
        value.contains('denied') ||
        value.contains('notallowed');
  }

  @override
  final String providerId = 'livekit';

  @override
  final MediaRole role;

  @override
  final MediaCapabilities capabilities;

  @override
  final MediaTrackRenderer renderer = const LiveKitTrackRenderer();

  lk.LocalVideoTrack? _cameraTrack;
  lk.LocalAudioTrack? _microphoneTrack;
  final _microphoneLevels = StreamController<double>.broadcast();
  lk.AudioVisualizer? _audioVisualizer;
  lk.EventsListener<lk.AudioVisualizerEvent>? _audioListener;

  @override
  Stream<double> get microphoneLevels => _microphoneLevels.stream;
  MediaDevice? _selectedMicrophone;
  MediaDevice? _selectedCamera;
  MediaDevice? _selectedOutput;
  MediaLocalPreviewSettings _settings;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);

  @override
  MediaVideoTrack? get cameraTrack {
    final track = _cameraTrack;
    if (track == null) return null;
    return LiveKitMediaVideoTrack(
      liveKitTrack: track,
      id: 'livekit-preview-${track.hashCode}',
      participantId: 'local-preview',
      isLocal: true,
      isScreenShare: false,
      width: 1280,
      height: 720,
    );
  }

  @override
  MediaLocalPreviewSettings get settings => _settings;

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    _ensureActive();
    final hardware = lk.Hardware.instance;
    final devices = <MediaDevice>[];
    if (kinds == null || kinds.contains(MediaDeviceKind.microphone)) {
      if (capabilities.canEnumerateMicrophones) {
        devices.addAll((await hardware.audioInputs()).map(_mapDevice));
      }
    }
    if (kinds == null || kinds.contains(MediaDeviceKind.camera)) {
      if (capabilities.canEnumerateCameras) {
        devices.addAll((await hardware.videoInputs()).map(_mapDevice));
      }
    }
    if (kinds == null || kinds.contains(MediaDeviceKind.audioOutput)) {
      if (capabilities.canEnumerateAudioDevices) {
        devices.addAll((await hardware.audioOutputs()).map(_mapDevice));
      }
    }
    return List.unmodifiable(devices);
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    _ensureActive();
    switch (device.kind) {
      case MediaDeviceKind.microphone:
        if (!capabilities.canSelectMicrophone) {
          throw _unsupported('Microphone selection');
        }
        _selectedMicrophone = device;
        if (_microphoneTrack != null) {
          await _microphoneTrack!.setDeviceId(device.id);
        } else if (!kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.windows)) {
          await lk.Hardware.instance.selectAudioInput(_toLiveKitDevice(device));
        }
        break;
      case MediaDeviceKind.camera:
        if (!capabilities.canSelectCamera) {
          throw _unsupported('Camera selection');
        }
        _selectedCamera = device;
        if (_cameraTrack != null) await _cameraTrack!.switchCamera(device.id);
        break;
      case MediaDeviceKind.audioOutput:
        if (!capabilities.canSelectAudioOutput) {
          throw _unsupported('Audio output selection');
        }
        _selectedOutput = device;
        await lk.Hardware.instance.selectAudioOutput(_toLiveKitDevice(device));
        break;
    }
    _refreshSettings();
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    _ensureActive();
    if (!capabilities.canPublishAudio) throw _unsupported('Microphone capture');
    if (enabled == _settings.microphoneEnabled) return;
    if (enabled) {
      try {
        final track = await lk.LocalAudioTrack.create(
          lk.AudioCaptureOptions(deviceId: _selectedMicrophone?.id),
        );
        if (_disposed) {
          await track.stop();
          _ensureActive();
        }
        _microphoneTrack = track;
        // The visualizer reads this exact local capture track, not an
        // animation or a second microphone stream. Meter failure must never
        // prevent publishing audio in a subsequent meeting.
        await _startAudioMeter(track);
      } catch (error) {
        throw RealtimeException(
          code: _isPermissionFailure(error)
              ? RealtimeErrorCode.permissionDenied
              : RealtimeErrorCode.providerError,
          message: 'Unable to start the LiveKit microphone check.',
          details: error,
          providerId: providerId,
        );
      }
    } else {
      await _stopAudioMeter();
      await _microphoneTrack?.stop();
      _microphoneTrack = null;
    }
    _refreshSettings(microphoneEnabled: enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    _ensureActive();
    if (!capabilities.canPublishVideo) throw _unsupported('Camera capture');
    if (enabled == _settings.cameraEnabled) return;
    if (enabled) {
      try {
        final track = await lk.LocalVideoTrack.createCameraTrack(
          lk.CameraCaptureOptions(deviceId: _selectedCamera?.id),
        );
        if (_disposed) {
          await track.stop();
          _ensureActive();
        }
        _cameraTrack = track;
      } catch (error) {
        throw RealtimeException(
          code: _isPermissionFailure(error)
              ? RealtimeErrorCode.permissionDenied
              : RealtimeErrorCode.providerError,
          message: 'Unable to start the LiveKit camera preview.',
          details: error,
          providerId: providerId,
        );
      }
    } else {
      await _cameraTrack?.stop();
      _cameraTrack = null;
    }
    _refreshSettings(cameraEnabled: enabled);
  }

  void _refreshSettings({bool? microphoneEnabled, bool? cameraEnabled}) {
    if (_disposed) return;
    _settings = MediaLocalPreviewSettings(
      microphoneEnabled: microphoneEnabled ?? _settings.microphoneEnabled,
      cameraEnabled: cameraEnabled ?? _settings.cameraEnabled,
      microphone: _selectedMicrophone,
      camera: _selectedCamera,
      audioOutput: _selectedOutput,
    );
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    final microphone = _microphoneTrack, camera = _cameraTrack;
    _microphoneTrack = null;
    _cameraTrack = null;
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await _stopAudioMeter();
    await cleanup.run('preview.microphone', () async {
      await microphone?.stop();
    });
    await cleanup.run('preview.camera', () async {
      await camera?.stop();
    });
    cleanup.finish(domain: 'media');
    await _microphoneLevels.close();
  }

  void _ensureActive() {
    if (_disposed) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidState,
        message: 'The local preview session has been disposed.',
        providerId: providerId,
      );
    }
  }

  RealtimeException _unsupported(String operation) => RealtimeException(
    code: RealtimeErrorCode.unsupportedFeature,
    message: '$operation is not supported by the LiveKit preview.',
    providerId: providerId,
  );
}

MediaDevice _mapDevice(lk.MediaDevice device) => MediaDevice(
  id: device.deviceId,
  label: device.label.isEmpty ? device.kind : device.label,
  kind: switch (device.kind) {
    'audioinput' => MediaDeviceKind.microphone,
    'videoinput' => MediaDeviceKind.camera,
    _ => MediaDeviceKind.audioOutput,
  },
  groupId: device.groupId,
);

lk.MediaDevice _toLiveKitDevice(MediaDevice device) =>
    lk.MediaDevice(device.id, device.label, switch (device.kind) {
      MediaDeviceKind.microphone => 'audioinput',
      MediaDeviceKind.camera => 'videoinput',
      MediaDeviceKind.audioOutput => 'audiooutput',
    }, device.groupId ?? '');
