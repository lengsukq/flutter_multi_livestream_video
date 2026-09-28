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

class DefaultMediaPermissionProbe implements MediaPermissionProbe {
  const DefaultMediaPermissionProbe();

  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return MediaPermissionState.unsupported;
    }
    try {
      final permission = switch (kind) {
        MediaPermissionKind.microphone => permissions.Permission.microphone,
        MediaPermissionKind.camera => permissions.Permission.camera,
      };
      final value = await permission.status;
      if (value.isGranted) return MediaPermissionState.granted;
      if (value.isPermanentlyDenied) {
        return MediaPermissionState.permanentlyDenied;
      }
      if (value.isRestricted) return MediaPermissionState.restricted;
      if (value.isLimited) return MediaPermissionState.limited;
      if (value.isProvisional) return MediaPermissionState.provisional;
      if (value.isDenied) return MediaPermissionState.denied;
      return MediaPermissionState.unknown;
    } catch (_) {
      return MediaPermissionState.unknown;
    }
  }
}
