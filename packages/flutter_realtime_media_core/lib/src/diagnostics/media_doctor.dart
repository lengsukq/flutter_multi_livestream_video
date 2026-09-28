import '../client/media_backend_client.dart';
import '../client/media_backend_error.dart';
import '../session/media_session_factory.dart';

enum MediaDoctorStatus { pass, warning, fail }

class MediaDoctorCheck {
  const MediaDoctorCheck({
    required this.id,
    required this.status,
    required this.message,
  });
  final String id;
  final MediaDoctorStatus status;
  final String message;
  bool get passed => status == MediaDoctorStatus.pass;
}

class MediaDoctorReport {
  const MediaDoctorReport(
    this.checks, {
    this.activeProvider,
    this.backendReachable = false,
  });
  final List<MediaDoctorCheck> checks;
  final String? activeProvider;
  final bool backendReachable;

  bool get healthy =>
      checks.every((item) => item.status != MediaDoctorStatus.fail);

  MediaDoctorCheck? checkById(String id) {
    for (final check in checks) {
      if (check.id == id) return check;
    }
    return null;
  }
}

/// Lightweight integration diagnostics that never creates a provider room.
class MediaDoctor {
  const MediaDoctor._();

  static Future<MediaDoctorReport> check({
    required MediaBackendClient backend,
    required MediaRegistry registry,
  }) async {
    final checks = <MediaDoctorCheck>[];
    String? activeProvider;
    var backendReachable = false;
    final providers = registry.providerIds.toList(growable: false);
    checks.add(
      MediaDoctorCheck(
        id: 'providers',
        status: providers.isEmpty
            ? MediaDoctorStatus.fail
            : MediaDoctorStatus.pass,
        message: providers.isEmpty
            ? 'No provider adapters are registered.'
            : 'Registered adapters: ${providers.join(', ')}.',
      ),
    );
    try {
      final health = await backend.health();
      backendReachable = true;
      final version = health['contractVersion'];
      checks.add(
        MediaDoctorCheck(
          id: 'backend',
          status: MediaDoctorStatus.pass,
          message: 'Backend is reachable (contract v${version ?? 'unknown'}).',
        ),
      );
      final active = health['activeProvider']?.toString().trim();
      if (active != null && active.isNotEmpty) {
        activeProvider = active.toLowerCase();
        checks.add(
          MediaDoctorCheck(
            id: 'active-provider',
            status: registry.lookup(active) == null
                ? MediaDoctorStatus.fail
                : MediaDoctorStatus.pass,
            message: registry.lookup(active) == null
                ? 'Backend selected $active, but its adapter is not registered.'
                : 'Backend active provider $active is registered.',
          ),
        );
      }
    } on MediaBackendError catch (error) {
      final unreachable =
          error.code == MediaBackendErrorCode.network ||
          error.code == MediaBackendErrorCode.timeout ||
          error.code == MediaBackendErrorCode.unsupportedPlatform;
      backendReachable = !unreachable;
      final optionalHealthUnavailable =
          error.statusCode == 404 ||
          error.code == MediaBackendErrorCode.unsupportedFeature ||
          error.code == MediaBackendErrorCode.invalidResponse ||
          error.code == MediaBackendErrorCode.unknown;
      checks.add(
        MediaDoctorCheck(
          id: 'backend',
          status: unreachable
              ? MediaDoctorStatus.fail
              : optionalHealthUnavailable
              ? MediaDoctorStatus.warning
              : MediaDoctorStatus.fail,
          message: unreachable
              ? 'Backend is unreachable: ${error.message}'
              : optionalHealthUnavailable
              ? 'Backend responded, but the optional health check is unavailable: '
                    '${error.message}'
              : 'Backend health check reported a failure: ${error.message}',
        ),
      );
    }
    return MediaDoctorReport(
      List.unmodifiable(checks),
      activeProvider: activeProvider,
      backendReachable: backendReachable,
    );
  }
}
