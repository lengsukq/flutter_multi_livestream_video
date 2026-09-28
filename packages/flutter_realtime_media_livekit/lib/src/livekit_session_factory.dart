import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'livekit_join_info.dart';
import 'livekit_media_session.dart';

typedef LiveKitDeviceCountLoader = Future<int> Function();

/// Registers LiveKit as a provider for [MediaClient].
class LiveKitSessionFactory implements MediaSessionFactory, MediaPreJoinProbe {
  const LiveKitSessionFactory({
    @visibleForTesting this.audioInputCountLoader,
    @visibleForTesting this.videoInputCountLoader,
  });

  @visibleForTesting
  final LiveKitDeviceCountLoader? audioInputCountLoader;

  @visibleForTesting
  final LiveKitDeviceCountLoader? videoInputCountLoader;

  @override
  String get providerId => LiveKitJoinInfo.providerIdValue;

  @override
  Set<MediaRole> get supportedRoles => const {
    MediaRole.participant,
    MediaRole.host,
    MediaRole.viewer,
  };

  @override
  LiveKitJoinInfo parseJoinInfo(Map<String, dynamic> json) =>
      LiveKitJoinInfo.fromBackendResponse(json);

  @override
  MediaSession createSession(MediaJoinInfo joinInfo) {
    if (joinInfo is! LiveKitJoinInfo) {
      throw const MediaError(
        code: MediaErrorCode.invalidJoinInfo,
        message: 'LiveKitSessionFactory requires LiveKitJoinInfo.',
        providerId: LiveKitJoinInfo.providerIdValue,
      );
    }
    return switch (joinInfo.role) {
      MediaRole.participant => LiveKitInteractiveSession(),
      MediaRole.host => LiveKitHostSession(),
      MediaRole.viewer => LiveKitViewerSession(),
    };
  }

  @override
  Future<MediaPreJoinProbeResult> runPreJoinProbe(
    MediaPreJoinProbeRequest request,
  ) async {
    final checks = <MediaPreJoinCheck>[];
    await _appendDeviceCheck(
      checks,
      type: MediaPreJoinCheckType.microphoneDevice,
      label: 'microphone',
      requirement: request.requirements.microphone,
      loader: audioInputCountLoader ?? _audioInputCount,
    );
    await _appendDeviceCheck(
      checks,
      type: MediaPreJoinCheckType.cameraDevice,
      label: 'camera',
      requirement: request.requirements.camera,
      loader: videoInputCountLoader ?? _videoInputCount,
    );
    if (request.requirements.network != MediaPreJoinRequirement.skipped) {
      checks.add(
        const MediaPreJoinCheck(
          type: MediaPreJoinCheckType.providerNetwork,
          status: MediaPreJoinStatus.unsupported,
          severity: MediaPreJoinSeverity.warning,
          message:
              'LiveKit native network probing requires provider-issued '
              'credentials, so Pre-Join does not create a room to simulate it.',
        ),
      );
    }
    return MediaPreJoinProbeResult(List.unmodifiable(checks));
  }

  Future<void> _appendDeviceCheck(
    List<MediaPreJoinCheck> checks, {
    required MediaPreJoinCheckType type,
    required String label,
    required MediaPreJoinRequirement requirement,
    required LiveKitDeviceCountLoader loader,
  }) async {
    if (requirement == MediaPreJoinRequirement.skipped) return;
    try {
      final deviceCount = await loader();
      checks.add(
        MediaPreJoinCheck(
          type: type,
          status: deviceCount == 0
              ? MediaPreJoinStatus.failed
              : MediaPreJoinStatus.passed,
          severity: requirement.severity,
          message: deviceCount == 0
              ? 'No $label device is available.'
              : 'Found $deviceCount $label device(s).',
        ),
      );
    } catch (error) {
      checks.add(
        MediaPreJoinCheck(
          type: type,
          status: MediaPreJoinStatus.unknown,
          severity: requirement.severity,
          message: 'Unable to enumerate LiveKit $label devices before joining.',
          details: error,
        ),
      );
    }
  }

  static Future<int> _audioInputCount() async =>
      (await lk.Hardware.instance.audioInputs()).length;

  static Future<int> _videoInputCount() async =>
      (await lk.Hardware.instance.videoInputs()).length;
}
