import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

enum MediaPermissionKind { microphone, camera }

enum MediaPermissionState {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  provisional,
  unsupported,
  unknown,
}

/// Provider-neutral permission status source used by Pre-Join checks.
///
/// The default implementation only reads the current status. It never requests
/// permission, so running Pre-Join cannot unexpectedly display an OS prompt.
///
/// Host applications using [DefaultMediaPermissionProbe] must configure the
/// underlying platform permissions. Android requires CAMERA/RECORD_AUDIO
/// manifest entries (and compileSdk 37+ for the current permission_handler
/// dependency). CocoaPods-based iOS apps require camera/microphone usage
/// descriptions plus PERMISSION_CAMERA=1 and PERMISSION_MICROPHONE=1 Podfile
/// preprocessor definitions. See PRE_JOIN_SETUP.md in this package.
abstract interface class MediaPermissionProbe {
  Future<MediaPermissionState> status(MediaPermissionKind kind);
}

/// Permission actions used by the pre-join page.
abstract interface class MediaPermissionRequester {
  Future<MediaPermissionState> status(MediaPermissionKind kind);

  Future<MediaPermissionState> request(MediaPermissionKind kind);

  bool get canOpenAppSettings;

  Future<bool> openAppSettings();
}

class DefaultMediaPermissionProbe
    implements MediaPermissionProbe, MediaPermissionRequester {
  const DefaultMediaPermissionProbe();

  bool get _isSupportedPlatform =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  permissions.Permission _permissionFor(MediaPermissionKind kind) =>
      switch (kind) {
        MediaPermissionKind.microphone => permissions.Permission.microphone,
        MediaPermissionKind.camera => permissions.Permission.camera,
      };

  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async {
    if (!_isSupportedPlatform) return MediaPermissionState.unsupported;
    try {
      return _stateFor(await _permissionFor(kind).status);
    } catch (_) {
      return MediaPermissionState.unknown;
    }
  }

  @override
  Future<MediaPermissionState> request(MediaPermissionKind kind) async {
    if (!_isSupportedPlatform) return MediaPermissionState.unsupported;
    try {
      return _stateFor(await _permissionFor(kind).request());
    } catch (_) {
      return MediaPermissionState.unknown;
    }
  }

  MediaPermissionState _stateFor(permissions.PermissionStatus value) {
    if (value.isGranted) return MediaPermissionState.granted;
    if (value.isPermanentlyDenied) {
      return MediaPermissionState.permanentlyDenied;
    }
    // permission_handler maps the browser's "prompt" state to denied. A
    // prompt means access has not been requested yet, so pre-join must leave
    // the decision to the user's explicit permission action.
    if (kIsWeb && value.isDenied) return MediaPermissionState.unknown;
    if (value.isRestricted) return MediaPermissionState.restricted;
    if (value.isLimited) return MediaPermissionState.limited;
    if (value.isProvisional) return MediaPermissionState.provisional;
    if (value.isDenied) return MediaPermissionState.denied;
    return MediaPermissionState.unknown;
  }

  @override
  bool get canOpenAppSettings =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> openAppSettings() async {
    if (!canOpenAppSettings) return false;
    try {
      return await permissions.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
