import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_media_session.dart';
import 'support/fake_transport.dart';

void main() {
  group('MediaClient.runPreJoinCheck', () {
    test('returns ready when required checks pass', () async {
      final factory = _ProbeFactory();
      final client = _client(
        factory: factory,
        permissionProbe: const _PermissionProbe(),
      );

      final result = await client.runPreJoinCheck(
        role: MediaRole.participant,
        requirements: const MediaPreJoinRequirements(
          microphone: MediaPreJoinRequirement.required,
          camera: MediaPreJoinRequirement.required,
        ),
      );

      expect(result.isReady, isTrue);
      expect(result.providerId, 'fake');
      expect(result.blockingIssues, isEmpty);
      expect(
        result.check(MediaPreJoinCheckType.microphoneDevice)?.status,
        MediaPreJoinStatus.passed,
      );
      expect(
        result.check(MediaPreJoinCheckType.providerNetwork)?.status,
        MediaPreJoinStatus.passed,
      );
      client.dispose();
    });

    test(
      'backend health failure blocks while network remains reachable',
      () async {
        final client = _client(
          factory: FakeMediaSessionFactory(),
          permissionProbe: const _PermissionProbe(),
          healthStatusCode: 503,
        );

        final result = await client.runPreJoinCheck(providerId: 'fake');

        expect(result.isReady, isFalse);
        expect(
          result.check(MediaPreJoinCheckType.backend)?.status,
          MediaPreJoinStatus.failed,
        );
        expect(result.check(MediaPreJoinCheckType.backend)?.isBlocking, isTrue);
        expect(
          result.check(MediaPreJoinCheckType.network)?.status,
          MediaPreJoinStatus.passed,
        );
        client.dispose();
      },
    );

    test(
      'required device check is blocking when provider has no probe',
      () async {
        final client = _client(
          factory: FakeMediaSessionFactory(),
          permissionProbe: const _PermissionProbe(),
        );

        final result = await client.runPreJoinCheck(
          requirements: const MediaPreJoinRequirements(
            microphone: MediaPreJoinRequirement.required,
            camera: MediaPreJoinRequirement.skipped,
          ),
        );

        final microphone = result.check(MediaPreJoinCheckType.microphoneDevice);
        expect(microphone?.status, MediaPreJoinStatus.unsupported);
        expect(microphone?.isBlocking, isTrue);
        expect(result.isReady, isFalse);
        client.dispose();
      },
    );

    test(
      'required device check is blocking when provider probe throws',
      () async {
        final client = _client(
          factory: _ThrowingProbeFactory(),
          permissionProbe: const _PermissionProbe(),
        );

        final result = await client.runPreJoinCheck(
          requirements: const MediaPreJoinRequirements(
            microphone: MediaPreJoinRequirement.required,
            camera: MediaPreJoinRequirement.skipped,
          ),
        );

        final microphone = result.check(MediaPreJoinCheckType.microphoneDevice);
        expect(microphone?.status, MediaPreJoinStatus.unknown);
        expect(microphone?.isBlocking, isTrue);
        expect(result.isReady, isFalse);
        client.dispose();
      },
    );

    test('missing optional health endpoint does not block joining', () async {
      final factory = _ProbeFactory();
      final transport = FakeTransport((request) {
        if (request.uri.path == '/health') {
          return jsonResponse({'message': 'Not found'}, statusCode: 404);
        }
        if (request.uri.path == '/rooms/discover') {
          return jsonResponse({
            'contractVersion': 1,
            'rooms': [
              {
                'roomCode': 'room-1',
                'provider': 'fake',
                'roomMode': 'meeting',
                'attendeeCount': 1,
              },
            ],
          });
        }
        throw StateError('Unexpected request: ${request.uri.path}');
      });
      final client = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: transport,
        permissionProbe: const _PermissionProbe(),
      );

      final result = await client.runPreJoinCheck(roomCode: 'room-1');

      expect(result.isReady, isTrue);
      expect(
        result.check(MediaPreJoinCheckType.backend)?.status,
        MediaPreJoinStatus.unknown,
      );
      expect(result.check(MediaPreJoinCheckType.backend)?.isBlocking, isFalse);
      expect(
        result.check(MediaPreJoinCheckType.network)?.status,
        MediaPreJoinStatus.passed,
      );
      expect(result.providerId, 'fake');
      client.dispose();
    });

    test('provider probe failures degrade to unknown warnings', () async {
      final client = _client(
        factory: _ThrowingProbeFactory(),
        permissionProbe: const _PermissionProbe(),
      );

      final result = await client.runPreJoinCheck();

      expect(result.isReady, isTrue);
      expect(
        result.check(MediaPreJoinCheckType.microphoneDevice)?.status,
        MediaPreJoinStatus.unknown,
      );
      expect(
        result.check(MediaPreJoinCheckType.cameraDevice)?.status,
        MediaPreJoinStatus.unknown,
      );
      expect(
        result.check(MediaPreJoinCheckType.providerNetwork)?.status,
        MediaPreJoinStatus.unknown,
      );
      expect(result.warnings, isNotEmpty);
      client.dispose();
    });

    test(
      'missing provider adapters are blocking even without active provider',
      () async {
        final transport = FakeTransport(
          (_) => jsonResponse({'contractVersion': 1}),
        );
        final client = MediaClient(
          backendUrl: 'https://example.test',
          registry: MediaRegistry(),
          transport: transport,
          permissionProbe: const _PermissionProbe(),
        );

        final result = await client.runPreJoinCheck();

        expect(result.isReady, isFalse);
        expect(
          result.check(MediaPreJoinCheckType.provider)?.status,
          MediaPreJoinStatus.failed,
        );
        client.dispose();
      },
    );

    test('backend network failure is blocking', () async {
      final client = _client(
        factory: FakeMediaSessionFactory(),
        permissionProbe: const _PermissionProbe(),
        healthError: const MediaBackendTransportException(
          'Connection refused.',
        ),
      );

      final result = await client.runPreJoinCheck();

      expect(result.isReady, isFalse);
      expect(
        result.check(MediaPreJoinCheckType.backend)?.status,
        MediaPreJoinStatus.failed,
      );
      expect(result.check(MediaPreJoinCheckType.network)?.isBlocking, isTrue);
      client.dispose();
    });

    test('required denied permission is blocking', () async {
      final client = _client(
        factory: _ProbeFactory(),
        permissionProbe: const _PermissionProbe(
          microphone: MediaPermissionState.denied,
        ),
      );

      final result = await client.runPreJoinCheck(
        requirements: const MediaPreJoinRequirements(
          microphone: MediaPreJoinRequirement.required,
          camera: MediaPreJoinRequirement.recommended,
        ),
      );

      expect(result.isReady, isFalse);
      expect(
        result.check(MediaPreJoinCheckType.microphonePermission)?.status,
        MediaPreJoinStatus.failed,
      );
      expect(
        result.check(MediaPreJoinCheckType.microphonePermission)?.isBlocking,
        isTrue,
      );
      client.dispose();
    });

    test('unsupported optional checks remain non-blocking', () async {
      final client = _client(
        factory: FakeMediaSessionFactory(),
        permissionProbe: const _PermissionProbe(
          microphone: MediaPermissionState.unsupported,
          camera: MediaPermissionState.unknown,
        ),
      );

      final result = await client.runPreJoinCheck();

      expect(result.isReady, isTrue);
      expect(
        result.check(MediaPreJoinCheckType.microphonePermission)?.status,
        MediaPreJoinStatus.unsupported,
      );
      expect(
        result.check(MediaPreJoinCheckType.microphoneDevice)?.status,
        MediaPreJoinStatus.unsupported,
      );
      expect(
        result.check(MediaPreJoinCheckType.providerNetwork)?.status,
        MediaPreJoinStatus.unsupported,
      );
      expect(result.warnings, isNotEmpty);
      client.dispose();
    });

    test('resolves existing room provider from discovery', () async {
      final factory = _ProbeFactory();
      final transport = FakeTransport((request) {
        if (request.uri.path == '/health') {
          return jsonResponse({
            'contractVersion': 1,
            'activeProvider': 'different-provider',
          });
        }
        if (request.uri.path == '/rooms/discover') {
          return jsonResponse({
            'contractVersion': 1,
            'rooms': [
              {
                'roomCode': 'room-1',
                'provider': 'fake',
                'roomMode': 'meeting',
                'attendeeCount': 1,
              },
            ],
          });
        }
        throw StateError('Unexpected request: ${request.uri.path}');
      });
      final client = MediaClient(
        backendUrl: 'https://example.test',
        registry: MediaRegistry([factory]),
        transport: transport,
        permissionProbe: const _PermissionProbe(),
      );

      final result = await client.runPreJoinCheck(roomCode: 'room-1');

      expect(result.providerId, 'fake');
      expect(
        result.check(MediaPreJoinCheckType.provider)?.status,
        MediaPreJoinStatus.passed,
      );
      client.dispose();
    });

    test('viewer skips microphone and camera checks', () async {
      final client = _client(
        factory: FakeMediaSessionFactory(),
        permissionProbe: const _PermissionProbe(
          microphone: MediaPermissionState.denied,
          camera: MediaPermissionState.denied,
        ),
      );

      final result = await client.runPreJoinCheck(role: MediaRole.viewer);

      expect(result.check(MediaPreJoinCheckType.microphonePermission), isNull);
      expect(result.check(MediaPreJoinCheckType.cameraPermission), isNull);
      expect(result.check(MediaPreJoinCheckType.microphoneDevice), isNull);
      expect(result.check(MediaPreJoinCheckType.cameraDevice), isNull);
      client.dispose();
    });

    test(
      'reports role-specific background capabilities from adapter',
      () async {
        final client = _client(
          factory: _BackgroundProbeFactory(),
          permissionProbe: const _PermissionProbe(),
        );

        final participant = await client.runPreJoinCheck(
          role: MediaRole.participant,
          providerId: 'fake',
        );
        final viewer = await client.runPreJoinCheck(
          role: MediaRole.viewer,
          providerId: 'fake',
        );

        expect(participant.backgroundCapabilities.canBlur, isTrue);
        expect(viewer.backgroundCapabilities.canBlur, isFalse);
        client.dispose();
      },
    );
  });
}

class _ThrowingProbeFactory extends FakeMediaSessionFactory
    implements MediaPreJoinProbe {
  @override
  Future<MediaPreJoinProbeResult> runPreJoinProbe(
    MediaPreJoinProbeRequest request,
  ) {
    throw StateError('probe failed');
  }
}

class _BackgroundProbeFactory extends _ProbeFactory
    implements MediaBackgroundCapabilitiesProvider {
  @override
  MediaBackgroundCapabilities backgroundCapabilitiesFor(MediaRole role) =>
      MediaBackgroundCapabilities(canBlur: role != MediaRole.viewer);
}

MediaClient _client({
  required MediaSessionFactory factory,
  required MediaPermissionProbe permissionProbe,
  int healthStatusCode = 200,
  Object? healthError,
}) {
  final transport = FakeTransport((request) {
    if (request.uri.path == '/health') {
      if (healthError != null) throw healthError;
      return jsonResponse({
        'contractVersion': 1,
        'activeProvider': 'fake',
      }, statusCode: healthStatusCode);
    }
    if (request.uri.path == '/rooms/discover') {
      return jsonResponse({'contractVersion': 1, 'rooms': <Object?>[]});
    }
    throw StateError('Unexpected request: ${request.uri.path}');
  });
  return MediaClient(
    backendUrl: 'https://example.test',
    registry: MediaRegistry([factory]),
    transport: transport,
    permissionProbe: permissionProbe,
  );
}

class _PermissionProbe implements MediaPermissionProbe {
  const _PermissionProbe({
    this.microphone = MediaPermissionState.granted,
    this.camera = MediaPermissionState.granted,
  });

  final MediaPermissionState microphone;
  final MediaPermissionState camera;

  @override
  Future<MediaPermissionState> status(MediaPermissionKind kind) async =>
      switch (kind) {
        MediaPermissionKind.microphone => microphone,
        MediaPermissionKind.camera => camera,
      };
}

class _ProbeFactory extends FakeMediaSessionFactory
    implements MediaPreJoinProbe {
  @override
  Future<MediaPreJoinProbeResult> runPreJoinProbe(
    MediaPreJoinProbeRequest request,
  ) async {
    final checks = <MediaPreJoinCheck>[];
    if (request.requirements.microphone != MediaPreJoinRequirement.skipped) {
      checks.add(
        const MediaPreJoinCheck(
          type: MediaPreJoinCheckType.microphoneDevice,
          status: MediaPreJoinStatus.passed,
          severity: MediaPreJoinSeverity.info,
          message: 'Microphone available.',
        ),
      );
    }
    if (request.requirements.camera != MediaPreJoinRequirement.skipped) {
      checks.add(
        const MediaPreJoinCheck(
          type: MediaPreJoinCheckType.cameraDevice,
          status: MediaPreJoinStatus.passed,
          severity: MediaPreJoinSeverity.info,
          message: 'Camera available.',
        ),
      );
    }
    if (request.requirements.network != MediaPreJoinRequirement.skipped) {
      checks.add(
        const MediaPreJoinCheck(
          type: MediaPreJoinCheckType.providerNetwork,
          status: MediaPreJoinStatus.passed,
          severity: MediaPreJoinSeverity.info,
          message: 'Provider network probe passed.',
        ),
      );
    }
    return MediaPreJoinProbeResult(checks);
  }
}
