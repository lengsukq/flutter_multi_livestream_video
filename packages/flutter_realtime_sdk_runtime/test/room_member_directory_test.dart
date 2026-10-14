import 'dart:async';

import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'unmatched local RTC presence is retained beside chat-only membership',
    () {
      final members = mergeSnapshotMembers(
        const [
          RoomManagedMember(
            userId: 'chat-user',
            displayName: 'Chat user',
            isSelf: true,
            chat: ChatMember(userId: 'chat-user'),
          ),
        ],
        MediaSnapshot(
          participants: const [
            MediaParticipant(
              id: 'media-user',
              displayName: 'Media user',
              isLocal: true,
            ),
          ],
        ),
      );
      expect(members, hasLength(2));
      expect(members.last.media?.participantId, 'media-user');
    },
  );

  test(
    'roster keeps administrative fields while adopting snapshot avatars',
    () {
      for (final id in ['local', 'different-provider-id']) {
        final joined = DateTime(2026);
        final members = mergeSnapshotMembers(
          [
            RoomManagedMember(
              userId: 'user',
              displayName: 'Backend name',
              isSelf: true,
              media: MediaRoomParticipantSummary(
                participantId: 'local',
                displayName: 'Backend name',
                userId: 'user',
                role: MediaRole.host,
                joinedAt: joined,
              ),
            ),
          ],
          MediaSnapshot(
            participants: [
              MediaParticipant(
                id: id,
                displayName: 'Presentation name',
                isLocal: true,
                avatarUrl: 'https://avatar.test/self.png',
              ),
            ],
          ),
        );
        expect(members, hasLength(1));
        expect(members.single.avatarUrl, 'https://avatar.test/self.png');
        expect(members.single.displayName, 'Backend name');
        expect(members.single.media?.participantId, 'local');
        expect(members.single.media?.role, MediaRole.host);
        expect(members.single.media?.joinedAt, joined);
      }
    },
  );

  test('live media snapshot fallback is usable without optional UI', () {
    final members = mergeSnapshotMembers(
      const [],
      MediaSnapshot(
        participants: const [
          MediaParticipant(
            id: 'presenter',
            displayName: 'Presenter',
            isLocal: true,
          ),
        ],
      ),
      localRole: MediaRole.host,
    );
    expect(members.single.userId, 'media:presenter');
    expect(members.single.media?.role, MediaRole.host);
    expect(members.single.isSelf, true);
  });
  test('logical identity merges media and chat membership once', () {
    final members = mergeRoomMembers(
      const [
        MediaRoomParticipantSummary(
          participantId: 'media-alice',
          userId: 'alice',
          displayName: 'Alice Video',
        ),
        MediaRoomParticipantSummary(
          participantId: 'anonymous',
          displayName: 'Guest Video',
        ),
      ],
      const [
        ChatMember(userId: 'alice', displayName: 'Alice Chat'),
        ChatMember(userId: 'chat-only', displayName: 'Chat User'),
      ],
      localMediaParticipantId: 'media-alice',
      localChatUserId: 'alice',
    );
    expect(members, hasLength(3));
    expect(members.first.userId, 'alice');
    expect(members.first.displayName, 'Alice Video');
    expect(members.first.media?.participantId, 'media-alice');
    expect(members.first.chat?.userId, 'alice');
    expect(members.first.isSelf, isTrue);
    expect(members[1].userId, 'media:anonymous');
    expect(members[1].chat, isNull);
    expect(members[2].userId, 'chat-only');
    expect(members[2].media, isNull);
    expect(members[2].isSelf, isFalse);
  });

  test('chat-only local identity is marked as self independently', () {
    final members = mergeRoomMembers(
      const [],
      const [ChatMember(userId: 'own-chat', displayName: 'Me')],
      localMediaParticipantId: 'different-media-id',
      localChatUserId: 'own-chat',
    );
    expect(members.single.isSelf, isTrue);
  });

  test('stale async member load cannot publish old-room members', () async {
    final moderation = _DelayedModeration();
    final room = MediaRoomSession.direct(
      roomCode: 'old-room',
      participantId: 'local',
      session: _StubMediaSession(),
    );
    addTearDown(room.dispose);
    final controller = RoomMembersController();
    var current = true;
    final request = controller.load(
      room,
      chatModeration: moderation,
      isCurrent: () => current,
    );
    await Future<void>.delayed(Duration.zero);
    current = false;
    moderation.release(const [ChatMember(userId: 'stale-member')]);
    final result = await request;
    expect(result.completed, isFalse);
    expect(result.members, isEmpty);
  });

  test(
    'host management goes through provider capabilities and rejects self',
    () async {
      final session = _HostMediaSession();
      final room = MediaRoomSession.direct(
        roomCode: 'room-1',
        participantId: 'host',
        session: session,
      );
      addTearDown(room.dispose);
      final controller = RoomMembersController();
      await controller.manageMedia(room, 'guest', RoomMediaMemberAction.mute);
      await controller.manageMedia(
        room,
        'guest',
        RoomMediaMemberAction.stopVideo,
      );
      await controller.manageMedia(
        room,
        'guest',
        RoomMediaMemberAction.grantHost,
      );
      await controller.manageMedia(room, 'guest', RoomMediaMemberAction.remove);
      expect(session.actions, [
        'mute:guest',
        'stopVideo:guest',
        'grantHost:guest',
        'remove:guest',
      ]);
      await expectLater(
        controller.manageMedia(room, 'host', RoomMediaMemberAction.remove),
        throwsA(isA<RealtimeException>()),
      );
      expect(session.actions, hasLength(4), reason: 'Self must not be removed');
    },
  );

  test('non-host member moderation is rejected before dispatch', () async {
    final room = MediaRoomSession.direct(
      roomCode: 'room-1',
      participantId: 'student',
      session: _StubMediaSession(),
    );
    addTearDown(room.dispose);
    await expectLater(
      RoomMembersController().manageMedia(
        room,
        'target',
        RoomMediaMemberAction.mute,
      ),
      throwsA(isA<RealtimeException>()),
    );
  });

  test(
    'chat member removal checks provider capability before dispatch',
    () async {
      final moderation = _ActionModeration();
      await RoomMembersController().removeChatMember(moderation, 'student');
      expect(moderation.removed, ['student']);
      await expectLater(
        RoomMembersController().removeChatMember(moderation, ''),
        throwsA(isA<RealtimeException>()),
      );
      expect(moderation.removed, ['student']);
    },
  );
}

class _DelayedModeration extends Fake
    implements ChatModeration, ChatModerationCapabilitySource {
  final Completer<List<ChatMember>> _pending = Completer();
  @override
  ChatManagementCapabilities get moderationCapabilities =>
      const ChatManagementCapabilities(
        listMembers: ChatManagementCapability.client(),
      );
  @override
  Future<List<ChatMember>> listMembers() => _pending.future;
  void release(List<ChatMember> members) => _pending.complete(members);
}

class _StubMediaSession extends Fake implements MediaSession {
  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => MediaRole.participant;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities.meeting();
  @override
  MediaSessionState get state => MediaSessionState.connected;
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaEvent> get events => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

class _HostMediaSession extends _StubMediaSession
    implements MediaRoomModeration {
  final actions = <String>[];
  @override
  MediaRole get role => MediaRole.host;
  @override
  MediaCapabilities get capabilities => const MediaCapabilities(
    management: MediaManagementCapabilities(
      removeParticipant: ManagementCapability.client(),
      muteParticipant: ManagementCapability.client(),
      stopParticipantVideo: ManagementCapability.client(),
      changeParticipantRole: ManagementCapability.client(),
    ),
  );
  @override
  Future<void> removeParticipant(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  }) async => actions.add('remove:$targetParticipantId');
  @override
  Future<void> muteParticipant(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  }) async => actions.add('mute:$targetParticipantId');
  @override
  Future<void> stopParticipantVideo(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    String? participantCredential,
    String? roomOwnerCredential,
  }) async => actions.add('stopVideo:$targetParticipantId');
  @override
  Future<void> changeParticipantRole(
    String roomCode, {
    required String requesterParticipantId,
    required String targetParticipantId,
    required MediaRole role,
    String? participantCredential,
    String? roomOwnerCredential,
  }) async => actions.add('grantHost:$targetParticipantId');
}

class _ActionModeration extends Fake
    implements ChatModeration, ChatModerationCapabilitySource {
  final removed = <String>[];
  @override
  ChatManagementCapabilities get moderationCapabilities =>
      const ChatManagementCapabilities(
        removeMember: ChatManagementCapability.backend(),
      );
  @override
  Future<void> removeMember(String userId) async => removed.add(userId);
}
