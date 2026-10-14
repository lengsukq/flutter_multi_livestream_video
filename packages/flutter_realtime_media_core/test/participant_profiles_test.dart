import 'dart:async';
import 'dart:convert';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'local profile follows the provider local member when IDs differ',
    () async {
      final session = _ProfileSession();
      final room = MediaRoomSession.direct(
        roomCode: 'profiles',
        participantId: 'backend-member',
        session: session,
        identity: const MediaIdentity(
          userId: 'logical-user',
          displayName: '本地',
          avatarUrl: 'https://avatar.test/self.png',
        ),
      );
      expect(room.snapshot.localParticipant?.id, 'self');
      expect(
        room.snapshot.localParticipant?.avatarUrl,
        'https://avatar.test/self.png',
      );
      expect(room.snapshot.participants.last.avatarUrl, isNull);
      await room.dispose();
    },
  );

  test(
    'profile hints are bound to a transport sender and preserve media state',
    () async {
      final session = _ProfileSession();
      final room = MediaRoomSession.direct(
        roomCode: 'profiles',
        participantId: 'self',
        session: session,
        identity: const MediaIdentity(
          userId: 'self',
          displayName: '本地',
          avatarUrl: 'https://avatar.test/self.png',
        ),
      );
      final snapshots = <MediaSnapshot>[];
      final subscription = room.snapshots.listen(snapshots.add);
      addTearDown(subscription.cancel);
      addTearDown(room.dispose);
      expect(
        room.snapshot.localParticipant!.avatarUrl,
        'https://avatar.test/self.png',
      );
      session.receive('remote', {
        'v': 1,
        'type': 'profile',
        'participantId': 'self',
        'displayName': '远端',
        'avatarUrl': 'https://avatar.test/remote.png',
      });
      await Future<void>.delayed(Duration.zero);
      final remote = room.snapshot.participants.last;
      expect(remote.displayName, '远端');
      expect(remote.avatarUrl, 'https://avatar.test/remote.png');
      expect(remote.isMuted, isTrue);
      expect(
        room.snapshot.localParticipant!.avatarUrl,
        'https://avatar.test/self.png',
      );
      session.receive('outsider', {
        'v': 1,
        'type': 'profile',
        'displayName': '伪造',
      });
      await Future<void>.delayed(Duration.zero);
      expect(room.snapshot.participants, hasLength(2));
      expect(snapshots.last.participants.last.displayName, '远端');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(session.sent.single.topic, 'realtime.profile.v1');
      await room.dispose();
      await room.dispose();
      expect(session.disposeCalls, 1);
    },
  );

  test('participant copies can preserve, replace and clear an avatar', () {
    const member = MediaParticipant(
      id: 'person',
      displayName: 'Ada',
      avatarUrl: 'https://avatar.test/ada.png',
    );
    expect(member.copyWith(isMuted: true).avatarUrl, member.avatarUrl);
    expect(
      member.copyWith(avatarUrl: 'https://avatar.test/new.png').avatarUrl,
      'https://avatar.test/new.png',
    );
    expect(member.copyWith(clearAvatarUrl: true).avatarUrl, isNull);
  });
}

class _ProfileSession extends Fake implements MediaSession, MediaDataMessenger {
  final _events = StreamController<MediaEvent>.broadcast();
  final sent = <({String message, String topic})>[];
  int disposeCalls = 0;
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  MediaSessionState get state => MediaSessionState.connected;
  @override
  MediaSnapshot get snapshot => MediaSnapshot(
    state: state,
    capabilities: capabilities,
    participants: const [
      MediaParticipant(id: 'self', displayName: 'Self', isLocal: true),
      MediaParticipant(id: 'remote', displayName: 'Remote', isMuted: true),
    ],
  );
  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaEvent> get events => _events.stream;
  void receive(String sender, Map<String, Object?> profile) => _events.add(
    MediaMessageReceived(
      MediaMessage(
        participantId: sender,
        message: jsonEncode(profile),
        topic: 'realtime.profile.v1',
        timestampMs: 1,
      ),
    ),
  );
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async =>
      sent.add((message: message, topic: topic));
  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _events.close();
  }
}
