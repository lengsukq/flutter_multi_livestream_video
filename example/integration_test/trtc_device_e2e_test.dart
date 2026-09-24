import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_trtc/flutter_realtime_media_trtc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _backendUrl = String.fromEnvironment('TRTC_E2E_BACKEND_URL');
const _token = String.fromEnvironment('TRTC_E2E_TOKEN');
const _roomCode = String.fromEnvironment('TRTC_E2E_ROOM_CODE');
const _nickname = String.fromEnvironment(
  'TRTC_E2E_NICKNAME',
  defaultValue: 'trtc-e2e',
);
const _roleName = String.fromEnvironment('TRTC_E2E_ROLE', defaultValue: 'host');
const _createRoom = bool.fromEnvironment(
  'TRTC_E2E_CREATE_ROOM',
  defaultValue: true,
);
const _runDeviceMedia = bool.fromEnvironment('TRTC_E2E_DEVICE_MEDIA');
const _expectRemoteParticipantCount = int.fromEnvironment(
  'TRTC_E2E_EXPECT_REMOTE_PARTICIPANTS',
  defaultValue: 0,
);
const _expectRemoteMessage = bool.fromEnvironment(
  'TRTC_E2E_EXPECT_REMOTE_MESSAGE',
);
const _expectRenewal = bool.fromEnvironment('TRTC_E2E_EXPECT_RENEWAL');
const _renderRemoteVideo = bool.fromEnvironment('TRTC_E2E_RENDER_REMOTE_VIDEO');
const _holdSeconds = int.fromEnvironment(
  'TRTC_E2E_HOLD_SECONDS',
  defaultValue: 0,
);
const _connectTimeoutSeconds = int.fromEnvironment(
  'TRTC_E2E_CONNECT_TIMEOUT_SECONDS',
  defaultValue: 45,
);
const _renewalTimeoutSeconds = int.fromEnvironment(
  'TRTC_E2E_RENEWAL_TIMEOUT_SECONDS',
  defaultValue: 75,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real device TRTC session lifecycle',
    (tester) async {
      expect(
        defaultTargetPlatform,
        anyOf(TargetPlatform.android, TargetPlatform.iOS),
      );
      final role = MediaRole.tryParse(_roleName);
      if (role == null) {
        fail('TRTC_E2E_ROLE must be participant, host, or viewer.');
      }
      if (!_createRoom && _roomCode.trim().isEmpty) {
        fail('TRTC_E2E_ROOM_CODE is required when TRTC_E2E_CREATE_ROOM=false.');
      }

      // This test deliberately registers only TRTC. Other adapters remain
      // optional and are not needed to resolve a TRTC room.
      final client = MediaClient(
        backendUrl: _backendUrl,
        registry: MediaRegistry([const TrtcSessionFactory()]),
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
      expect(room.providerId, 'trtc');
      expect(session.providerId, 'trtc');
      await _waitForState(
        session,
        MediaSessionState.connected,
        timeout: Duration(seconds: _connectTimeoutSeconds),
      );
      final renewalFuture = _expectRenewal
          ? session.states.firstWhere(
              (state) => state == MediaSessionState.reconnecting,
            )
          : null;

      if (role == MediaRole.viewer) {
        expect(session, isA<BroadcastViewerSession>());
        expect(session, isNot(isA<InteractiveMediaSession>()));
        expect(session.capabilities.canPublishAudio, isFalse);
        expect(session.capabilities.canPublishVideo, isFalse);
        expect(session.capabilities.canSendData, isFalse);
        await expectLater(
          (session as BroadcastViewerSession).sendMessage('not allowed'),
          throwsA(isA<MediaError>()),
        );
      } else {
        expect(session, isA<InteractiveMediaSession>());
        final interactive = session as InteractiveMediaSession;
        if (_runDeviceMedia) {
          await interactive
              .setMuted(false)
              .timeout(const Duration(seconds: 15));
          await interactive
              .setVideoEnabled(true)
              .timeout(const Duration(seconds: 15));
          await interactive
              .switchCamera(MediaCameraPosition.back)
              .timeout(const Duration(seconds: 15));
          await interactive
              .switchCamera(MediaCameraPosition.front)
              .timeout(const Duration(seconds: 15));
          final localTrack = session.snapshot.localParticipant?.videoTrack;
          expect(localTrack, isA<TrtcMediaVideoTrack>());
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: MediaTrackView(
                renderer: const TrtcTrackRenderer(),
                track: localTrack,
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 2));
        }
      }

      if (_expectRemoteParticipantCount > 0) {
        await _waitForRemoteParticipantCount(
          session,
          _expectRemoteParticipantCount,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
      }
      if (role != MediaRole.viewer) {
        await (session as InteractiveMediaSession)
            .sendMessage(
              'trtc-e2e-${DateTime.now().millisecondsSinceEpoch}',
              topic: 'trtc-e2e',
            )
            .timeout(const Duration(seconds: 10));
      }
      if (_renderRemoteVideo) {
        final track = await _waitForRemoteVideo(
          session,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaTrackView(
              renderer: const TrtcTrackRenderer(),
              track: track,
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
      }
      if (_expectRemoteMessage && role == MediaRole.viewer) {
        await _waitForRemoteMessage(
          session,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
      }

      if (_expectRenewal) {
        await renewalFuture!.timeout(Duration(seconds: _renewalTimeoutSeconds));
        await _waitForState(
          session,
          MediaSessionState.connected,
          timeout: Duration(seconds: _connectTimeoutSeconds),
        );
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
    timeout: const Timeout(Duration(minutes: 4)),
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
    fail('Expected TRTC state $expected, but reached $state.');
  }
}

Future<void> _waitForRemoteParticipantCount(
  MediaSession session,
  int count, {
  required Duration timeout,
}) async {
  bool reached(MediaSnapshot snapshot) =>
      snapshot.remoteParticipants.length >= count;
  if (reached(session.snapshot)) return;
  await session.snapshots.firstWhere(reached).timeout(timeout);
}

Future<MediaVideoTrack> _waitForRemoteVideo(
  MediaSession session, {
  required Duration timeout,
}) async {
  MediaVideoTrack? firstTrack(MediaSnapshot snapshot) {
    for (final participant in snapshot.remoteParticipants) {
      if (participant.videoTrack != null) return participant.videoTrack;
    }
    return null;
  }

  final existing = firstTrack(session.snapshot);
  if (existing != null) return existing;
  return session.snapshots
      .map(firstTrack)
      .firstWhere((track) => track != null)
      .then((track) => track!)
      .timeout(timeout);
}

Future<void> _waitForRemoteMessage(
  MediaSession session, {
  required Duration timeout,
}) async {
  bool received(MediaSnapshot snapshot) =>
      snapshot.messages.any((message) => message.topic == 'trtc-e2e');
  if (received(session.snapshot)) return;
  await session.snapshots.firstWhere(received).timeout(timeout);
}
