import 'package:flutter_aws_chime/flutter_aws_chime.dart' as chime;
import 'package:flutter_multi_livestream_video_chime/flutter_multi_livestream_video_chime.dart';
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_chime_session.dart';

void main() {
  Map<String, dynamic> backendJson({String role = 'participant'}) => {
    'contractVersion': 1,
    'provider': 'chime',
    'role': role,
    'roomCode': '482913',
    'participantId': 'attendee-local',
    'meeting': {
      'MeetingId': 'meeting-id',
      'ExternalMeetingId': 'room-482913',
      'MediaRegion': 'ap-southeast-1',
      'MediaPlacement': {
        'AudioHostUrl': 'https://audio.example',
        'AudioFallbackUrl': 'https://fallback.example',
        'SignalingUrl': 'wss://signal.example',
        'TurnControlUrl': 'https://turn.example',
      },
    },
    'attendee': {
      'AttendeeId': 'attendee-local',
      'ExternalUserId': 'Local User',
      'JoinToken': 'short-lived-token',
    },
  };

  group('ChimeJoinInfo', () {
    test('wraps the existing Chime JoinInfo without changing its payload', () {
      final info = ChimeJoinInfo.fromBackendResponse(backendJson());

      expect(info.providerId, 'chime');
      expect(info.role, MediaRole.participant);
      expect(info.roomCode, '482913');
      expect(info.participantId, 'attendee-local');
      expect(info.chimeJoinInfo.meeting.meetingId, 'meeting-id');
      expect(info.chimeJoinInfo.attendee.joinToken, 'short-lived-token');
    });

    test('rejects broadcast roles until Chime can enforce them', () {
      expect(
        () => ChimeJoinInfo.fromBackendResponse(backendJson(role: 'viewer')),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
    });
  });

  group('ChimeMediaSession', () {
    late FakeChimeMeetingSession providerSession;
    late ChimeMediaSession session;
    late ChimeJoinInfo joinInfo;

    setUp(() {
      providerSession = FakeChimeMeetingSession();
      session = ChimeMediaSession(session: providerSession);
      joinInfo = ChimeJoinInfo.fromBackendResponse(backendJson());
    });

    test('maps join state and the local attendee', () async {
      await session.join(joinInfo);

      expect(session.state, MediaSessionState.connected);
      expect(session.snapshot.localParticipantId, 'attendee-local');
      expect(session.snapshot.localParticipant?.displayName, 'Local User');
      expect(session.capabilities.canPublishVideo, isTrue);
      expect(session.capabilities.canScreenShare, isFalse);
      await session.dispose();
    });

    test(
      'maps remote participants, video tiles, speaking, and messages',
      () async {
        await session.join(joinInfo);
        final events = <MediaEvent>[];
        final subscription = session.events.listen(events.add);

        providerSession.emitRemoteParticipant(
          id: 'remote-a',
          name: 'Remote A',
          videoTile: const chime.MeetingVideoTile(
            tileId: 7,
            attendeeId: 'remote-a',
            width: 1280,
            height: 720,
            isLocal: false,
            isContentShare: false,
          ),
        );
        providerSession.emitVolume('remote-a', chime.MeetingVolumeLevel.high);
        await session.sendMessage('hello', topic: 'chat');
        await pumpEventQueue();

        final remote = session.snapshot.remoteParticipants.single;
        expect(remote.id, 'remote-a');
        expect(remote.videoTrack, isA<ChimeMediaVideoTrack>());
        expect(remote.isSpeaking, isTrue);
        expect(session.snapshot.messages.single.message, 'hello');
        expect(events.whereType<MediaParticipantJoined>(), isNotEmpty);
        expect(events.whereType<MediaTrackPublished>(), isNotEmpty);
        expect(events.whereType<MediaSpeakingChanged>(), isNotEmpty);
        expect(events.whereType<MediaMessageReceived>(), isNotEmpty);

        providerSession.removeParticipant('remote-a');
        await pumpEventQueue();
        expect(session.snapshot.remoteParticipants, isEmpty);
        expect(events.whereType<MediaParticipantLeft>(), isNotEmpty);

        await subscription.cancel();
        await session.dispose();
      },
    );

    test(
      'delegates controls and rejects unsupported outgoing screen share',
      () async {
        await session.join(joinInfo);

        await session.setMuted(false);
        await session.setVideoEnabled(true);
        await session.switchCamera(MediaCameraPosition.back);
        final devices = await session.listAudioDevices();
        await session.selectAudioDevice(devices.single);

        expect(providerSession.actions, contains('muted:false'));
        expect(providerSession.actions, contains('video:true'));
        expect(providerSession.actions, contains('camera:back'));
        expect(providerSession.actions, contains('audio:Speaker'));
        await expectLater(
          session.setScreenShareEnabled(true),
          throwsA(
            isA<MediaError>().having(
              (error) => error.code,
              'code',
              MediaErrorCode.unsupportedFeature,
            ),
          ),
        );
        await session.dispose();
      },
    );

    test(
      'dispose is idempotent through the existing provider session',
      () async {
        await session.join(joinInfo);
        await session.dispose();
        await session.dispose();

        expect(session.state, MediaSessionState.disposed);
        expect(
          providerSession.actions.where((item) => item == 'dispose').length,
          1,
        );
      },
    );
  });

  test('factory registers only the role Chime currently guarantees', () {
    final fake = FakeChimeMeetingSession();
    final factory = ChimeSessionFactory(sessionFactory: () => fake);
    final info = ChimeJoinInfo.fromBackendResponse(backendJson());

    expect(factory.providerId, 'chime');
    expect(factory.supportedRoles, {MediaRole.participant});
    expect(factory.createSession(info).chimeSession, same(fake));
  });
}
