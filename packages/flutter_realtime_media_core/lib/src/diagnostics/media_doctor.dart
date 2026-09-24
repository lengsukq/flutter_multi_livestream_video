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
  const MediaDoctorReport(this.checks);
  final List<MediaDoctorCheck> checks;
  bool get healthy =>
      checks.every((item) => item.status != MediaDoctorStatus.fail);
}

/// Lightweight integration diagnostics that never creates a provider room.
class MediaDoctor {
  const MediaDoctor._();

  static Future<MediaDoctorReport> check({
    required MediaBackendClient backend,
    required MediaRegistry registry,
  }) async {
    final checks = <MediaDoctorCheck>[];
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
      checks.add(
        MediaDoctorCheck(
          id: 'backend',
          status: MediaDoctorStatus.fail,
          message: 'Backend check failed: ${error.message}',
        ),
      );
    }
    return MediaDoctorReport(List.unmodifiable(checks));
  }
}
