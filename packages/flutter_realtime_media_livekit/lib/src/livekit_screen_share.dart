part of 'livekit_media_session.dart';

class _LiveKitScreenShare {
  _LiveKitScreenShare(this._session);
  final LiveKitMediaSessionBase _session;
  bool _androidScreenShareServiceStarted = false;
  Future<void> _prepareAndroidScreenShare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    // System annotation windows must be visible in the shared display; an
    // Android single-app projection excludes windows belonging to other apps.
    final permissionGranted = await rtc.Helper.requestCapturePermission(
      fullScreenOnly: true,
    );
    if (!permissionGranted) {
      throw RealtimeException(
        code: RealtimeErrorCode.permissionDenied,
        message: 'Screen-capture permission was denied.',
        providerId: _session.providerId,
      );
    }

    await _androidScreenShareChannel.invokeMethod<void>('start');
    _androidScreenShareServiceStarted = true;
  }

  Future<void> _prepareMacOsScreenShare() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return;

    final permissionGranted = await rtc.Helper.requestCapturePermission();
    if (!permissionGranted) {
      throw RealtimeException(
        code: RealtimeErrorCode.permissionDenied,
        message:
            'LiveKit screen sharing needs macOS Screen Recording permission. '
            'Allow it in System Settings > Privacy & Security > Screen Recording, '
            'then restart the app.',
        providerId: _session.providerId,
      );
    }
  }

  Future<void> _stopAndroidScreenShareService() async {
    if (!_androidScreenShareServiceStarted ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _androidScreenShareServiceStarted = false;
    await _androidScreenShareChannel.invokeMethod<void>('stop');
  }
}
