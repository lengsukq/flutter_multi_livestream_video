import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_aws_chime/flutter_aws_chime.dart';

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

      final client = ChimeClient(
        backendUrl: _backendUrl,
        tokenProvider: _token.trim().isEmpty ? null : () => _token,
      );
      ChimeRoomSession? room;

      addTearDown(() async {
        await room?.dispose();
        client.dispose();
      });

      room = _createRoom
          ? await client.createRoomAndJoin(
              roomCode: _roomCode.trim().isEmpty ? null : _roomCode,
              nickname: _nickname,
            )
          : await client.joinRoom(roomCode: _roomCode, nickname: _nickname);

      final session = room.session;
      await _waitForState(
        session,
        MeetingState.connected,
        timeout: Duration(seconds: _connectTimeoutSeconds),
      );

      expect(session.snapshot.localAttendee, isNotNull);

      await session.setMuted(false);
      expect(session.snapshot.localMuted, isFalse);
      await session.setMuted(true);
      expect(session.snapshot.localMuted, isTrue);

      final audioDevices = await session.listAudioDevices();
      if (audioDevices.isNotEmpty) {
        final preferred = audioDevices.firstWhere(
          (device) => device.type == ChimeAudioDeviceType.speaker,
          orElse: () => audioDevices.first,
        );
        await session.selectAudioDevice(preferred);
        expect(session.snapshot.selectedAudioDevice?.label, preferred.label);
      }

      await session.setVideoEnabled(true);
      expect(session.snapshot.localVideoEnabled, isTrue);

      if (!_skipCameraSwitch) {
        await session.switchCamera(CameraPosition.back);
        await session.switchCamera(CameraPosition.front);
      }

      final message = 'device-e2e-${DateTime.now().millisecondsSinceEpoch}';
      await session.sendMessage(message, topic: 'e2e');
      expect(
        session.snapshot.messages.any(
          (item) => item.topic == 'e2e' && item.message == message,
        ),
        isTrue,
      );

      if (_expectRemoteAttendee) {
        await _waitForRemoteAttendee(
          session,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
      }

      if (_holdSeconds > 0) {
        await Future<void>.delayed(Duration(seconds: _holdSeconds));
      }

      await session.setVideoEnabled(false);
      expect(session.snapshot.localVideoEnabled, isFalse);

      await room.leave();
      expect(session.state, MeetingState.ended);

      await room.dispose();
      expect(session.state, MeetingState.disposed);
    },
    skip: _backendUrl.trim().isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _waitForState(
  ChimeMeetingSession session,
  MeetingState expected, {
  required Duration timeout,
}) async {
  if (session.state == expected) return;

  final state = await session.states
      .firstWhere(
        (value) =>
            value == expected ||
            value == MeetingState.failed ||
            value == MeetingState.ended ||
            value == MeetingState.disposed,
      )
      .timeout(timeout);

  if (state != expected) {
    fail('Expected meeting state $expected, but reached $state instead.');
  }
}

Future<void> _waitForRemoteAttendee(
  ChimeMeetingSession session, {
  required Duration timeout,
}) async {
  bool hasRemote(MeetingSnapshot snapshot) =>
      snapshot.attendees.any((attendee) => !attendee.isLocal);

  if (hasRemote(session.snapshot)) return;

  await session.snapshots.firstWhere(hasRemote).timeout(timeout);
}
