import '../model/media_role.dart';
import 'media_pre_join.dart';

class MediaPreJoinProbeRequest {
  const MediaPreJoinProbeRequest({
    required this.providerId,
    required this.role,
    required this.requirements,
  });

  final String providerId;
  final MediaRole role;
  final MediaPreJoinRequirements requirements;
}

class MediaPreJoinProbeResult {
  const MediaPreJoinProbeResult(this.checks);

  final List<MediaPreJoinCheck> checks;
}

/// Optional adapter hook for checks that can safely run before joining.
///
/// Implementations must not create a room or consume normal join credentials.
/// If a provider requires credentials to perform a native network test, report
/// that check as unsupported/unknown instead of simulating success.
abstract interface class MediaPreJoinProbe {
  Future<MediaPreJoinProbeResult> runPreJoinProbe(
    MediaPreJoinProbeRequest request,
  );
}
