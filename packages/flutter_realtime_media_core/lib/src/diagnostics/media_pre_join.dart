import '../model/media_background_effect.dart';
import '../model/media_role.dart';

enum MediaPreJoinStatus { passed, failed, unsupported, unknown }

enum MediaPreJoinSeverity { info, warning, blocking }

enum MediaPreJoinCheckType {
  backend,
  provider,
  microphonePermission,
  cameraPermission,
  microphoneDevice,
  cameraDevice,
  network,
  providerNetwork,
}

enum MediaPreJoinRequirement { skipped, recommended, required }

extension MediaPreJoinRequirementSeverity on MediaPreJoinRequirement {
  MediaPreJoinSeverity get severity => switch (this) {
    MediaPreJoinRequirement.skipped => MediaPreJoinSeverity.info,
    MediaPreJoinRequirement.recommended => MediaPreJoinSeverity.warning,
    MediaPreJoinRequirement.required => MediaPreJoinSeverity.blocking,
  };
}

class MediaPreJoinRequirements {
  const MediaPreJoinRequirements({
    this.microphone = MediaPreJoinRequirement.recommended,
    this.camera = MediaPreJoinRequirement.recommended,
    this.network = MediaPreJoinRequirement.required,
  });

  const MediaPreJoinRequirements.viewer()
    : microphone = MediaPreJoinRequirement.skipped,
      camera = MediaPreJoinRequirement.skipped,
      network = MediaPreJoinRequirement.required;

  final MediaPreJoinRequirement microphone;
  final MediaPreJoinRequirement camera;
  final MediaPreJoinRequirement network;

  factory MediaPreJoinRequirements.forRole(MediaRole role) =>
      role == MediaRole.viewer
      ? const MediaPreJoinRequirements.viewer()
      : const MediaPreJoinRequirements();
}

class MediaPreJoinRequest {
  const MediaPreJoinRequest({
    this.role = MediaRole.participant,
    this.providerId,
    this.roomCode,
    this.requirements,
  });

  final MediaRole role;
  final String? providerId;
  final String? roomCode;
  final MediaPreJoinRequirements? requirements;

  MediaPreJoinRequirements get effectiveRequirements =>
      requirements ?? MediaPreJoinRequirements.forRole(role);
}

class MediaPreJoinCheck {
  const MediaPreJoinCheck({
    required this.type,
    required this.status,
    required this.severity,
    required this.message,
    this.details,
  });

  final MediaPreJoinCheckType type;
  final MediaPreJoinStatus status;
  final MediaPreJoinSeverity severity;
  final String message;
  final Object? details;

  bool get passed => status == MediaPreJoinStatus.passed;

  bool get isBlocking =>
      severity == MediaPreJoinSeverity.blocking &&
      status != MediaPreJoinStatus.passed;
}

class MediaPreJoinResult {
  const MediaPreJoinResult({
    required this.role,
    required this.checks,
    this.providerId,
    this.backgroundCapabilities = const MediaBackgroundCapabilities.none(),
  });

  final MediaRole role;
  final String? providerId;
  final List<MediaPreJoinCheck> checks;
  final MediaBackgroundCapabilities backgroundCapabilities;

  bool get isReady => blockingIssues.isEmpty;

  List<MediaPreJoinCheck> get blockingIssues =>
      List.unmodifiable(checks.where((check) => check.isBlocking));

  List<MediaPreJoinCheck> get warnings => List.unmodifiable(
    checks.where(
      (check) =>
          check.severity == MediaPreJoinSeverity.warning && !check.passed,
    ),
  );

  MediaPreJoinCheck? check(MediaPreJoinCheckType type) {
    for (final item in checks) {
      if (item.type == type) return item;
    }
    return null;
  }
}
