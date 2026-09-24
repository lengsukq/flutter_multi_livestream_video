import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveKitJoinInfo', () {
    test('parses the provider block and preserves the requested role', () {
      final info = LiveKitJoinInfo.fromBackendResponse({
        'provider': 'livekit',
        'role': 'host',
        'roomCode': '482913',
        'participantId': 'host-a',
        'displayName': 'Host A',
        'livekit': {
          'url': 'wss://example.livekit.cloud',
          'token': 'short-lived-token',
          'identity': 'host-a',
        },
      });

      expect(info.providerId, 'livekit');
      expect(info.role, MediaRole.host);
      expect(info.roomCode, '482913');
      expect(info.participantId, 'host-a');
      expect(info.identity, 'host-a');
      expect(info.displayName, 'Host A');
    });

    test('uses livekit.identity when the common participant id is absent', () {
      final info = LiveKitJoinInfo.fromBackendResponse({
        'provider': 'livekit',
        'role': 'viewer',
        'roomCode': '482913',
        'livekit': {
          'url': 'ws://127.0.0.1:7880',
          'token': 'short-lived-token',
          'identity': 'viewer-a',
        },
      });

      expect(info.participantId, 'viewer-a');
      expect(info.role, MediaRole.viewer);
    });

    test('rejects an identity mismatch', () {
      expect(
        () => LiveKitJoinInfo.fromBackendResponse({
          'provider': 'livekit',
          'roomCode': '482913',
          'participantId': 'participant-a',
          'livekit': {
            'url': 'ws://127.0.0.1:7880',
            'token': 'short-lived-token',
            'identity': 'participant-b',
          },
        }),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidJoinInfo,
          ),
        ),
      );
    });

    test('rejects another provider and a missing provider block', () {
      expect(
        () => LiveKitJoinInfo.fromBackendResponse({
          'provider': 'chime',
          'roomCode': '482913',
        }),
        throwsA(isA<MediaError>()),
      );
      expect(
        () => LiveKitJoinInfo.fromBackendResponse({
          'provider': 'livekit',
          'roomCode': '482913',
          'participantId': 'host-a',
        }),
        throwsA(isA<MediaError>()),
      );
    });
  });

  group('LiveKitSessionFactory', () {
    const factory = LiveKitSessionFactory();

    LiveKitJoinInfo info(MediaRole role) => LiveKitJoinInfo(
      roomCode: '482913',
      participantId: role.name,
      role: role,
      url: 'ws://127.0.0.1:7880',
      token: 'short-lived-token',
      identity: role.name,
    );

    test('creates role-specific session surfaces', () {
      final participant = factory.createSession(info(MediaRole.participant));
      final host = factory.createSession(info(MediaRole.host));
      final viewer = factory.createSession(info(MediaRole.viewer));

      expect(participant, isA<LiveKitInteractiveSession>());
      expect(host, isA<LiveKitHostSession>());
      expect(host, isA<BroadcastHostSession>());
      expect(viewer, isA<LiveKitViewerSession>());
      expect(viewer, isA<BroadcastViewerSession>());
      expect(viewer, isNot(isA<InteractiveMediaSession>()));
      expect(viewer.capabilities.canPublishAudio, isFalse);
      expect(viewer.capabilities.canPublishVideo, isFalse);
    });

    test('rejects generic join info', () {
      final generic = MediaJoinInfo(
        providerId: 'livekit',
        roomCode: '482913',
        participantId: 'generic',
        role: MediaRole.participant,
      );
      expect(
        () => factory.createSession(generic),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidJoinInfo,
          ),
        ),
      );
    });
  });
}
