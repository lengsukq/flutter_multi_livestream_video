import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_strings.dart';

/// Provider-independent permission probing and Pre-Join check projection.
///
/// UI owns dialogs/snackbars; the coordinator owns permission semantics and
/// has no dependency on BuildContext, Widget lifecycle or room navigation.
class PreJoinPermissionCoordinator {
  const PreJoinPermissionCoordinator(this.requester);

  final MediaPermissionRequester requester;

  bool get canOpenAppSettings => requester.canOpenAppSettings;

  Future<Map<MediaPermissionKind, MediaPermissionState>> readStatuses() async =>
      {for (final kind in MediaPermissionKind.values) kind: await status(kind)};

  Future<MediaPermissionState> status(MediaPermissionKind kind) async {
    try {
      return await requester.status(kind);
    } catch (_) {
      return MediaPermissionState.unknown;
    }
  }

  Future<MediaPermissionState> request(MediaPermissionKind kind) =>
      requester.request(kind);

  Future<bool> openAppSettings() => requester.openAppSettings();

  MediaPreJoinResult projectCheck({
    required MediaPreJoinResult result,
    required MediaPermissionKind kind,
    required MediaPermissionState state,
    required RealtimeStrings strings,
  }) {
    final type = kind == MediaPermissionKind.microphone
        ? MediaPreJoinCheckType.microphonePermission
        : MediaPreJoinCheckType.cameraPermission;
    final original = result.check(type);
    if (original == null) return result;
    final status = switch (state) {
      MediaPermissionState.granted => MediaPreJoinStatus.passed,
      MediaPermissionState.denied ||
      MediaPermissionState.permanentlyDenied ||
      MediaPermissionState.restricted => MediaPreJoinStatus.failed,
      MediaPermissionState.unsupported => MediaPreJoinStatus.unsupported,
      MediaPermissionState.limited ||
      MediaPermissionState.provisional ||
      MediaPermissionState.unknown => MediaPreJoinStatus.unknown,
    };
    final label = kind == MediaPermissionKind.microphone
        ? strings.microphone
        : strings.camera;
    final message = switch (state) {
      MediaPermissionState.granted => strings.permissionGranted(label),
      MediaPermissionState.denied => strings.permissionDenied(label),
      MediaPermissionState.permanentlyDenied =>
        canOpenAppSettings
            ? strings.permissionPermanentlyDenied(label)
            : strings.permissionBrowserHelp(label),
      MediaPermissionState.restricted => strings.permissionRestricted(label),
      MediaPermissionState.unsupported ||
      MediaPermissionState.limited ||
      MediaPermissionState.provisional => original.message,
      MediaPermissionState.unknown => strings.permissionDenied(label),
    };
    final updated = MediaPreJoinCheck(
      type: original.type,
      status: status,
      severity: original.severity,
      message: message,
      details: original.details,
    );
    return MediaPreJoinResult(
      role: result.role,
      providerId: result.providerId,
      backgroundCapabilities: result.backgroundCapabilities,
      checks: [
        for (final check in result.checks) check.type == type ? updated : check,
      ],
    );
  }
}
