import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _backendUrl = String.fromEnvironment('AGORA_E2E_BACKEND_URL');
const _token = String.fromEnvironment('AGORA_E2E_TOKEN');
const _roomCode = String.fromEnvironment('AGORA_E2E_ROOM_CODE');
const _nickname = String.fromEnvironment(
  'AGORA_E2E_NICKNAME',
  defaultValue: 'agora-e2e',
);
const _roleName = String.fromEnvironment(
  'AGORA_E2E_ROLE',
  defaultValue: 'host',
);
const _createRoom = bool.fromEnvironment(
  'AGORA_E2E_CREATE_ROOM',
  defaultValue: true,
);
const _runDeviceMedia = bool.fromEnvironment('AGORA_E2E_DEVICE_MEDIA');
const _expectRemoteParticipant = bool.fromEnvironment(
  'AGORA_E2E_EXPECT_REMOTE_PARTICIPANT',
);
const _expectRemoteMessage = bool.fromEnvironment(
  'AGORA_E2E_EXPECT_REMOTE_MESSAGE',
);
const _holdSeconds = int.fromEnvironment(
  'AGORA_E2E_HOLD_SECONDS',
  defaultValue: 0,
);
const _connectTimeoutSeconds = int.fromEnvironment(
  'AGORA_E2E_CONNECT_TIMEOUT_SECONDS',
  defaultValue: 45,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real device Agora session lifecycle',
    (tester) async {
      expect(
        defaultTargetPlatform,
        anyOf(TargetPlatform.android, TargetPlatform.iOS),
      );

      final role = MediaRole.tryParse(_roleName);
      if (role == null) {
        fail('AGORA_E2E_ROLE must be participant, host, or viewer.');
      }
      if (!_createRoom && _roomCode.trim().isEmpty) {
        fail(
          'AGORA_E2E_ROOM_CODE is required when '
          'AGORA_E2E_CREATE_ROOM=false.',
        );
      }

      final client = MediaClient(
        backendUrl: _backendUrl,
        registry: MediaRegistry([const AgoraSessionFactory()]),
        tokenProvider: _token.trim().isEmpty ? null : () => _token,
        heartbeatInterval: const Duration(seconds: 2),
      );
      MediaRoomSession? room;

      addTearDown(() async {
        await room?.dispose();
        client.dispose();
      });

      room = _createRoom
          ? await client
                .createRoomAndJoin(
                  roomCode: _roomCode.trim().isEmpty ? null : _roomCode,
                  nickname: _nickname,
                  role: role,
                )
                .timeout(Duration(seconds: _connectTimeoutSeconds))
          : await client
                .joinRoom(roomCode: _roomCode, nickname: _nickname, role: role)
                .timeout(Duration(seconds: _connectTimeoutSeconds));

      final session = room.session;
      expect(room.providerId, 'agora');
      expect(session.providerId, 'agora');
      await _waitForState(
        session,
        MediaSessionState.connected,
        timeout: Duration(seconds: _connectTimeoutSeconds),
      );
      expect(session.snapshot.localParticipant, isNotNull);

      if (role == MediaRole.viewer) {
        expect(session, isA<AgoraViewerSession>());
        expect(session, isNot(isA<InteractiveMediaSession>()));
        expect(session.capabilities.canPublishAudio, isFalse);
        expect(session.capabilities.canPublishVideo, isFalse);
        expect(session.capabilities.canSendData, isFalse);
      } else {
        expect(session, isA<InteractiveMediaSession>());
        final interactive = session as InteractiveMediaSession;

        if (_runDeviceMedia) {
          await interactive
              .setMuted(false)
              .timeout(const Duration(seconds: 15));
          expect(session.snapshot.localMuted, isFalse);
          await interactive
              .setVideoEnabled(true)
              .timeout(const Duration(seconds: 15));
          expect(session.snapshot.localVideoEnabled, isTrue);
          await interactive
              .switchCamera(MediaCameraPosition.back)
              .timeout(const Duration(seconds: 15));
          await interactive
              .switchCamera(MediaCameraPosition.front)
              .timeout(const Duration(seconds: 15));
        }
      }

      if (_expectRemoteParticipant) {
        await _waitForRemoteParticipant(
          session,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
      }

      if (role != MediaRole.viewer) {
        final interactive = session as InteractiveMediaSession;
        await interactive
            .sendMessage(
              'agora-e2e-${DateTime.now().millisecondsSinceEpoch}',
              topic: 'e2e',
            )
            .timeout(const Duration(seconds: 10));
      }

      if (_expectRemoteMessage) {
        await _waitForRemoteMessage(
          session,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
      }

      if (role != MediaRole.viewer && _runDeviceMedia) {
        final interactive = session as InteractiveMediaSession;
        await interactive
            .setVideoEnabled(false)
            .timeout(const Duration(seconds: 15));
        await interactive.setMuted(true).timeout(const Duration(seconds: 15));
      }

      if (_holdSeconds > 0) {
        await Future<void>.delayed(Duration(seconds: _holdSeconds));
      }

      await room.leave().timeout(const Duration(seconds: 15));
      expect(session.state, MediaSessionState.ended);
      await room.dispose().timeout(const Duration(seconds: 15));
      expect(session.state, MediaSessionState.disposed);
    },
    skip: _backendUrl.trim().isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _waitForState(
  MediaSession session,
  MediaSessionState expected, {
  required Duration timeout,
}) async {
  if (session.state == expected) return;

  final state = await session.states
      .firstWhere(
        (value) =>
            value == expected ||
            value == MediaSessionState.failed ||
            value == MediaSessionState.ended ||
            value == MediaSessionState.disposed,
      )
      .timeout(timeout);

  if (state != expected) {
    fail('Expected Agora state $expected, but reached $state instead.');
  }
}

Future<void> _waitForRemoteParticipant(
  MediaSession session, {
  required Duration timeout,
}) async {
  bool hasRemote(MediaSnapshot snapshot) =>
      snapshot.remoteParticipants.isNotEmpty;

  if (hasRemote(session.snapshot)) return;
  await session.snapshots.firstWhere(hasRemote).timeout(timeout);
}

Future<void> _waitForRemoteMessage(
  MediaSession session, {
  required Duration timeout,
}) async {
  bool hasMessage(MediaSnapshot snapshot) =>
      snapshot.messages.any((message) => message.topic == 'e2e');

  if (hasMessage(session.snapshot)) return;
  await session.snapshots.firstWhere(hasMessage).timeout(timeout);
}
