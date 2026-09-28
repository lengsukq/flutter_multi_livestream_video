import '../client/media_backend_client.dart';
import '../session/media_session_factory.dart';
import 'media_doctor.dart';
import 'media_permission_probe.dart';
import 'media_pre_join.dart';
import 'media_pre_join_probe.dart';

class MediaPreJoinRunner {
  const MediaPreJoinRunner({
    required this.backend,
    required this.registry,
    required this.permissionProbe,
  });

  final MediaBackendClient backend;
  final MediaRegistry registry;
  final MediaPermissionProbe permissionProbe;

  Future<MediaPreJoinResult> run(MediaPreJoinRequest request) async {
    final checks = <MediaPreJoinCheck>[];
    final requirements = request.effectiveRequirements;
    final doctor = await MediaDoctor.check(
      backend: backend,
      registry: registry,
    );
    final backendCheck = doctor.checkById('backend');
    final backendStatus = backendCheck?.status ?? MediaDoctorStatus.fail;
    final backendReachable = doctor.backendReachable;

    checks.add(
      MediaPreJoinCheck(
        type: MediaPreJoinCheckType.backend,
        status: switch (backendStatus) {
          MediaDoctorStatus.pass => MediaPreJoinStatus.passed,
          MediaDoctorStatus.warning => MediaPreJoinStatus.unknown,
          MediaDoctorStatus.fail => MediaPreJoinStatus.failed,
        },
        severity: backendStatus == MediaDoctorStatus.fail
            ? MediaPreJoinSeverity.blocking
            : backendStatus == MediaDoctorStatus.warning
            ? MediaPreJoinSeverity.warning
            : MediaPreJoinSeverity.info,
        message: backendCheck?.message ?? 'Backend check did not complete.',
      ),
    );
    if (requirements.network != MediaPreJoinRequirement.skipped) {
      checks.add(
        MediaPreJoinCheck(
          type: MediaPreJoinCheckType.network,
          status: backendReachable
              ? MediaPreJoinStatus.passed
              : MediaPreJoinStatus.failed,
          severity: requirements.network.severity,
          message: backendReachable
              ? 'Basic network path to the media backend is available.'
              : 'The media backend is not reachable over the current network.',
        ),
      );
    }

    final resolvedProvider = await _resolveProvider(
      request,
      doctor,
      backendReachable: backendReachable,
    );
    final factory = resolvedProvider == null
        ? null
        : registry.lookup(resolvedProvider);
    checks.add(_providerCheck(request, resolvedProvider, factory));

    await _appendPermissionChecks(checks, request);

    if (factory != null && resolvedProvider != null) {
      await _appendProviderProbe(
        checks,
        factory: factory,
        providerId: resolvedProvider,
        request: request,
      );
    } else {
      _appendUnknownProviderChecks(checks, request);
    }

    return MediaPreJoinResult(
      role: request.role,
      providerId: resolvedProvider,
      checks: List.unmodifiable(checks),
    );
  }

  Future<String?> _resolveProvider(
    MediaPreJoinRequest request,
    MediaDoctorReport doctor, {
    required bool backendReachable,
  }) async {
    final explicit = request.providerId?.trim().toLowerCase();
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final roomCode = request.roomCode?.trim();
    if (roomCode != null && roomCode.isNotEmpty) {
      if (!backendReachable) return null;
      try {
        final rooms = await backend.listRooms();
        for (final room in rooms) {
          if (room.roomCode == roomCode) return room.providerId;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
    return doctor.activeProvider;
  }

  MediaPreJoinCheck _providerCheck(
    MediaPreJoinRequest request,
    String? providerId,
    MediaSessionFactory? factory,
  ) {
    if (providerId == null) {
      if (registry.providerIds.isEmpty) {
        return const MediaPreJoinCheck(
          type: MediaPreJoinCheckType.provider,
          status: MediaPreJoinStatus.failed,
          severity: MediaPreJoinSeverity.blocking,
          message: 'No provider adapters are registered.',
        );
      }
      return const MediaPreJoinCheck(
        type: MediaPreJoinCheckType.provider,
        status: MediaPreJoinStatus.unknown,
        severity: MediaPreJoinSeverity.warning,
        message:
            'The target provider could not be resolved before joining. '
            'The backend may still choose it when join credentials are issued.',
      );
    }
    if (factory == null) {
      return MediaPreJoinCheck(
        type: MediaPreJoinCheckType.provider,
        status: MediaPreJoinStatus.failed,
        severity: MediaPreJoinSeverity.blocking,
        message: 'No adapter is registered for provider "$providerId".',
      );
    }
    if (!factory.supportedRoles.contains(request.role)) {
      return MediaPreJoinCheck(
        type: MediaPreJoinCheckType.provider,
        status: MediaPreJoinStatus.failed,
        severity: MediaPreJoinSeverity.blocking,
        message:
            'Provider "$providerId" does not support the '
            '${request.role.wireName} role.',
      );
    }
    return MediaPreJoinCheck(
      type: MediaPreJoinCheckType.provider,
      status: MediaPreJoinStatus.passed,
      severity: MediaPreJoinSeverity.info,
      message:
          'Provider "$providerId" is registered and supports the '
          '${request.role.wireName} role.',
    );
  }

  Future<void> _appendPermissionChecks(
    List<MediaPreJoinCheck> checks,
    MediaPreJoinRequest request,
  ) async {
    final requirements = request.effectiveRequirements;
    await _appendPermissionCheck(
      checks,
      type: MediaPreJoinCheckType.microphonePermission,
      kind: MediaPermissionKind.microphone,
      requirement: requirements.microphone,
      label: 'Microphone',
    );
    await _appendPermissionCheck(
      checks,
      type: MediaPreJoinCheckType.cameraPermission,
      kind: MediaPermissionKind.camera,
      requirement: requirements.camera,
      label: 'Camera',
    );
  }

  Future<void> _appendPermissionCheck(
    List<MediaPreJoinCheck> checks, {
    required MediaPreJoinCheckType type,
    required MediaPermissionKind kind,
    required MediaPreJoinRequirement requirement,
    required String label,
  }) async {
    if (requirement == MediaPreJoinRequirement.skipped) return;
    final state = await permissionProbe.status(kind);
    checks.add(
      MediaPreJoinCheck(
        type: type,
        status: _permissionStatus(state),
        severity: requirement.severity,
        message: _permissionMessage(label, state),
      ),
    );
  }

  Future<void> _appendProviderProbe(
    List<MediaPreJoinCheck> checks, {
    required MediaSessionFactory factory,
    required String providerId,
    required MediaPreJoinRequest request,
  }) async {
    if (factory is! MediaPreJoinProbe) {
      _appendUnsupportedProviderChecks(checks, request);
      return;
    }
    final probe = factory as MediaPreJoinProbe;
    try {
      final result = await probe.runPreJoinProbe(
        MediaPreJoinProbeRequest(
          providerId: providerId,
          role: request.role,
          requirements: request.effectiveRequirements,
        ),
      );
      checks.addAll(result.checks);
    } catch (error) {
      _appendUnknownProviderChecks(checks, request, details: error);
    }
  }

  void _appendUnsupportedProviderChecks(
    List<MediaPreJoinCheck> checks,
    MediaPreJoinRequest request,
  ) {
    final requirements = request.effectiveRequirements;
    _appendDeviceFallback(
      checks,
      type: MediaPreJoinCheckType.microphoneDevice,
      requirement: requirements.microphone,
      status: MediaPreJoinStatus.unsupported,
      message: 'This provider does not expose pre-join microphone enumeration.',
    );
    _appendDeviceFallback(
      checks,
      type: MediaPreJoinCheckType.cameraDevice,
      requirement: requirements.camera,
      status: MediaPreJoinStatus.unsupported,
      message: 'This provider does not expose pre-join camera enumeration.',
    );
    if (requirements.network != MediaPreJoinRequirement.skipped) {
      checks.add(
        const MediaPreJoinCheck(
          type: MediaPreJoinCheckType.providerNetwork,
          status: MediaPreJoinStatus.unsupported,
          severity: MediaPreJoinSeverity.warning,
          message:
              'This provider cannot run a native network probe without '
              'provider-issued diagnostic credentials.',
        ),
      );
    }
  }

  void _appendUnknownProviderChecks(
    List<MediaPreJoinCheck> checks,
    MediaPreJoinRequest request, {
    Object? details,
  }) {
    final requirements = request.effectiveRequirements;
    _appendDeviceFallback(
      checks,
      type: MediaPreJoinCheckType.microphoneDevice,
      requirement: requirements.microphone,
      status: MediaPreJoinStatus.unknown,
      message: 'Microphone availability could not be checked before joining.',
      details: details,
    );
    _appendDeviceFallback(
      checks,
      type: MediaPreJoinCheckType.cameraDevice,
      requirement: requirements.camera,
      status: MediaPreJoinStatus.unknown,
      message: 'Camera availability could not be checked before joining.',
      details: details,
    );
    if (requirements.network != MediaPreJoinRequirement.skipped) {
      checks.add(
        MediaPreJoinCheck(
          type: MediaPreJoinCheckType.providerNetwork,
          status: MediaPreJoinStatus.unknown,
          severity: MediaPreJoinSeverity.warning,
          message: 'Provider-specific network quality could not be checked.',
          details: details,
        ),
      );
    }
  }

  void _appendDeviceFallback(
    List<MediaPreJoinCheck> checks, {
    required MediaPreJoinCheckType type,
    required MediaPreJoinRequirement requirement,
    required MediaPreJoinStatus status,
    required String message,
    Object? details,
  }) {
    if (requirement == MediaPreJoinRequirement.skipped) return;
    checks.add(
      MediaPreJoinCheck(
        type: type,
        status: status,
        severity: requirement.severity,
        message: message,
        details: details,
      ),
    );
  }

  MediaPreJoinStatus _permissionStatus(MediaPermissionState state) =>
      switch (state) {
        MediaPermissionState.granted => MediaPreJoinStatus.passed,
        MediaPermissionState.denied ||
        MediaPermissionState.permanentlyDenied ||
        MediaPermissionState.restricted => MediaPreJoinStatus.failed,
        MediaPermissionState.unsupported => MediaPreJoinStatus.unsupported,
        MediaPermissionState.limited ||
        MediaPermissionState.provisional ||
        MediaPermissionState.unknown => MediaPreJoinStatus.unknown,
      };

  String _permissionMessage(
    String label,
    MediaPermissionState state,
  ) => switch (state) {
    MediaPermissionState.granted => '$label permission is granted.',
    MediaPermissionState.denied => '$label permission is denied.',
    MediaPermissionState.permanentlyDenied =>
      '$label permission is permanently denied. Open system settings to enable it.',
    MediaPermissionState.restricted =>
      '$label permission is restricted by the operating system.',
    MediaPermissionState.limited =>
      '$label permission is limited by the operating system.',
    MediaPermissionState.provisional => '$label permission is provisional.',
    MediaPermissionState.unsupported =>
      '$label permission status is not exposed on this platform.',
    MediaPermissionState.unknown =>
      '$label permission status could not be determined.',
  };
}
