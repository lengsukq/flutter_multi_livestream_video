import 'package:flutter/foundation.dart';
import 'package:flutter_multi_livestream_video_chime/flutter_multi_livestream_video_chime.dart';
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _backendUrl = String.fromEnvironment('CHIME_E2E_BACKEND_URL');
const _token = String.fromEnvironment('CHIME_E2E_TOKEN');
const _roomCode = String.fromEnvironment('CHIME_E2E_ROOM_CODE');
const _nickname = String.fromEnvironment(
  'CHIME_E2E_NICKNAME',
  defaultValue: 'flutter-e2e',
);
const _createRoom = bool.fromEnvironment(
  'CHIME_E2E_CREATE_ROOM',
  defaultValue: true,
);
const _skipCameraSwitch = bool.fromEnvironment('CHIME_E2E_SKIP_CAMERA_SWITCH');
const _expectRemoteAttendee = bool.fromEnvironment(
  'CHIME_E2E_EXPECT_REMOTE_ATTENDEE',
);
const _holdSeconds = int.fromEnvironment(
  'CHIME_E2E_HOLD_SECONDS',
  defaultValue: 0,
);
const _connectTimeoutSeconds = int.fromEnvironment(
  'CHIME_E2E_CONNECT_TIMEOUT_SECONDS',
  defaultValue: 45,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real device Chime meeting lifecycle',
    (tester) async {
      expect(
        defaultTargetPlatform,
        anyOf(TargetPlatform.android, TargetPlatform.iOS),
      );

      if (!_createRoom && _roomCode.trim().isEmpty) {
        fail(
          'CHIME_E2E_ROOM_CODE is required when '
          'CHIME_E2E_CREATE_ROOM=false.',
        );
      }

      final client = MediaClient(
        backendUrl: _backendUrl,
        registry: MediaRegistry([ChimeSessionFactory()]),
        tokenProvider: _token.trim().isEmpty ? null : () => _token,
      );
      MediaRoomSession? room;

      addTearDown(() async {
        await room?.dispose();
        client.dispose();
      });

      room = _createRoom
          ? await client.createRoomAndJoin(
              roomCode: _roomCode.trim().isEmpty ? null : _roomCode,
              nickname: _nickname,
              role: MediaRole.participant,
            )
          : await client.joinRoom(
              roomCode: _roomCode,
              nickname: _nickname,
              role: MediaRole.participant,
            );

      final session = room.session;
      expect(room.providerId, 'chime');
      expect(session, isA<ChimeMediaSession>());
      await _waitForState(
        session,
        MediaSessionState.connected,
        timeout: Duration(seconds: _connectTimeoutSeconds),
      );

      expect(session.snapshot.localParticipant, isNotNull);
      final interactive = session as InteractiveMediaSession;

      await interactive.setMuted(false);
      expect(session.snapshot.localMuted, isFalse);
      await interactive.setMuted(true);
      expect(session.snapshot.localMuted, isTrue);

      final audioDevices = await interactive.listAudioDevices();
      if (audioDevices.isNotEmpty) {
        final preferred = audioDevices.firstWhere(
          (device) => device.type == MediaAudioDeviceType.speaker,
          orElse: () => audioDevices.first,
        );
        await interactive.selectAudioDevice(preferred);
      }

      await interactive.setVideoEnabled(true);
      expect(session.snapshot.localVideoEnabled, isTrue);

      if (!_skipCameraSwitch) {
        await interactive.switchCamera(MediaCameraPosition.back);
        await interactive.switchCamera(MediaCameraPosition.front);
      }

      final message = 'device-e2e-${DateTime.now().millisecondsSinceEpoch}';
      await interactive.sendMessage(message, topic: 'e2e');
      expect(
        session.snapshot.messages.any(
          (item) => item.topic == 'e2e' && item.message == message,
        ),
        isTrue,
      );

      if (_expectRemoteAttendee) {
        await _waitForRemoteParticipant(
          session,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
      }

      if (_holdSeconds > 0) {
        await Future<void>.delayed(Duration(seconds: _holdSeconds));
      }

      await interactive.setVideoEnabled(false);
      expect(session.snapshot.localVideoEnabled, isFalse);

      await room.leave();
      expect(session.state, MediaSessionState.ended);

      await room.dispose();
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
    fail('Expected meeting state $expected, but reached $state instead.');
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
