import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'provider_web_profile.dart';

MediaCapabilities providerWebCapabilities(
  ProviderWebProfile profile,
  MediaRole role,
) {
  final isViewer = role == MediaRole.viewer;
  final canScreenShare = !isViewer && _browserSupportsScreenShare;
  final canEnumerateDevices = _browserSupportsDeviceEnumeration;
  final canSelectAudioOutput =
      profile.supportsAudioOutputSelection &&
      _browserSupportsAudioOutputSelection;
  final canManageParticipants =
      role == MediaRole.host && profile.canManageParticipants;
  return MediaCapabilities(
    canRecordCloud: false,
    canPublishAudio: !isViewer,
    canPublishVideo: !isViewer,
    canBlurBackground:
        !isViewer && profile.canBlurBackground && browserSupportsVideoEffects,
    canReplaceBackgroundImage:
        !isViewer &&
        profile.canReplaceBackgroundImage &&
        browserSupportsVideoEffects,
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

bool get browserSupportsVideoEffects {
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
