import 'dart:async';

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_rtc/flutter_realtime_chat_rtc.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:test/test.dart';

void main() {
  group('RtcDataChatSession', () {
    test(
      'resolver prefers configured product chat and never silently falls back',
      () async {
        final media = _FakeMediaSession(
          participantId: 'participant-a',
          displayName: 'Alice',
        );
        final room = _fakeRoom(media);
        final product = _FakeProductChatSession();

        expect(
          resolveChatSessionWithRtcFallback(
            room: room,
            productChatConfigured: true,
            productChatSession: product,
          ),
          same(product),
        );
        expect(
          resolveChatSessionWithRtcFallback(
            room: room,
            productChatConfigured: true,
            productChatSession: null,
          ),
          isNull,
        );

        await product.dispose();
        await room.dispose();
      },
    );

    test(
      'resolver falls back only for fully bidirectional media data',
      () async {
        final supportedMedia = _FakeMediaSession(
          participantId: 'participant-a',
          displayName: 'Alice',
        );
        final supportedRoom = _fakeRoom(supportedMedia);
        final supported = resolveChatSessionWithRtcFallback(
          room: supportedRoom,
          productChatConfigured: false,
        );
        expect(supported, isA<RtcDataChatSession>());
        await supported?.dispose();
        await supportedRoom.dispose();

        final receiveOnlyMedia = _FakeMediaSession(
          participantId: 'viewer-a',
          displayName: 'Viewer',
          role: MediaRole.viewer,
          canSendData: false,
          canReceiveData: true,
        );
        final receiveOnlyRoom = _fakeRoom(receiveOnlyMedia);
        expect(
          resolveChatSessionWithRtcFallback(
            room: receiveOnlyRoom,
            productChatConfigured: false,
          ),
          isNull,
        );
        await receiveOnlyRoom.dispose();
      },
    );

    test('requires full bidirectional RTC data capability', () async {
      final media = _FakeMediaSession(
        participantId: 'viewer-1',
        displayName: 'Viewer',
        role: MediaRole.viewer,
        canSendData: false,
        canReceiveData: true,
      );

      expect(RtcDataChatSession.canAttach(media), isFalse);
      expect(
        () => RtcDataChatSession.forSession(
          session: media,
          roomCode: 'room',
          participantId: 'viewer-1',
        ),
        throwsA(
          isA<ChatError>().having(
            (error) => error.code,
            'code',
            ChatErrorCode.unsupportedFeature,
          ),
        ),
      );
      await media.dispose();
    });

    test(
      'two clients exchange messages and provider echo is deduplicated',
      () async {
        final bus = _FakeDataBus();
        final mediaA = _FakeMediaSession(
          participantId: 'participant-a',
          displayName: 'Alice',
          bus: bus,
        );
        final mediaB = _FakeMediaSession(
          participantId: 'participant-b',
          displayName: 'Bob',
          bus: bus,
        );
        final chatA = RtcDataChatSession.forSession(
          session: mediaA,
          roomCode: 'room',
          participantId: 'participant-a',
          userId: 'user-a',
          displayName: 'Alice',
        );
        final chatB = RtcDataChatSession.forSession(
          session: mediaB,
          roomCode: 'room',
          participantId: 'participant-b',
          userId: 'user-b',
          displayName: 'Bob',
        );

        expect(chatA.state, ChatConnectionState.connected);
        expect(chatB.state, ChatConnectionState.connected);

        await chatA.sendMessage('hello Bob');
        await Future<void>.delayed(Duration.zero);

        expect(chatA.messages, hasLength(1));
        expect(chatB.messages, hasLength(1));
        expect(chatA.messages.single.message, 'hello Bob');
        expect(chatB.messages.single.message, 'hello Bob');
        expect(chatB.messages.single.userId, 'user-a');
        expect(chatB.messages.single.displayName, 'Alice');
        expect(chatB.messages.single.topic, rtcDataChatTopic);
        expect(chatB.messages.single.type, 'message');
        expect(chatB.messages.single.providerId, 'rtc-data:fake');
        expect(chatB.messages.single.attributes['mediaProviderId'], 'fake');

        await chatB.sendMessage('hello Alice');
        await Future<void>.delayed(Duration.zero);

        expect(chatA.messages, hasLength(2));
        expect(chatB.messages, hasLength(2));
        expect(chatA.messages.last.message, 'hello Alice');
        expect(chatA.messages.last.userId, 'user-b');

        await chatA.dispose();
        await chatB.dispose();
        await mediaA.dispose();
        await mediaB.dispose();
      },
    );

    test(
      'ignores RTC debug payloads and mirrors reconnect lifecycle',
      () async {
        final bus = _FakeDataBus();
        final media = _FakeMediaSession(
          participantId: 'participant-a',
          displayName: 'Alice',
          bus: bus,
        );
        final chat = RtcDataChatSession.forSession(
          session: media,
          roomCode: 'room',
          participantId: 'participant-a',
        );

        bus.publishRaw(sender: media, message: 'debug-only', topic: 'debug');
        await Future<void>.delayed(Duration.zero);
        expect(chat.messages, isEmpty);

        media.setState(MediaSessionState.reconnecting);
        await Future<void>.delayed(Duration.zero);
        expect(chat.state, ChatConnectionState.reconnecting);
        media.setState(MediaSessionState.connected);
        await Future<void>.delayed(Duration.zero);
        expect(chat.state, ChatConnectionState.connected);

        await chat.dispose();
        expect(chat.state, ChatConnectionState.disposed);
        bus.publishRaw(
          sender: media,
          message: 'after-dispose',
          topic: rtcDataChatTopic,
        );
        await Future<void>.delayed(Duration.zero);
        expect(chat.messages, isEmpty);
        expect(
          () => chat.sendMessage('nope'),
          throwsA(
            isA<ChatError>().having(
              (error) => error.code,
              'code',
              ChatErrorCode.invalidState,
            ),
          ),
        );
        await media.dispose();
      },
    );

    test(
      'viewer chat does not grant audio or video publish capability',
      () async {
        final bus = _FakeDataBus();
        final viewerMedia = _FakeMediaSession(
          participantId: 'viewer-1',
          displayName: 'Viewer',
          role: MediaRole.viewer,
          canSendData: true,
          canReceiveData: true,
          bus: bus,
        );
        final hostMedia = _FakeMediaSession(
          participantId: 'host-1',
          displayName: 'Host',
          role: MediaRole.host,
          bus: bus,
        );
        final viewerChat = RtcDataChatSession.forSession(
          session: viewerMedia,
          roomCode: 'room',
          participantId: 'viewer-1',
        );
        final hostChat = RtcDataChatSession.forSession(
          session: hostMedia,
          roomCode: 'room',
          participantId: 'host-1',
        );

        expect(viewerMedia.capabilities.canPublishAudio, isFalse);
        expect(viewerMedia.capabilities.canPublishVideo, isFalse);
        expect(viewerChat.role, ChatRole.viewer);
        expect(viewerChat.capabilities.canSendMessage, isTrue);

        await viewerChat.sendMessage('viewer can chat');
        await Future<void>.delayed(Duration.zero);
        expect(hostChat.messages.single.message, 'viewer can chat');
        expect(viewerMedia.capabilities.canPublishAudio, isFalse);
        expect(viewerMedia.capabilities.canPublishVideo, isFalse);

        await viewerChat.dispose();
        await hostChat.dispose();
        await viewerMedia.dispose();
        await hostMedia.dispose();
      },
    );
  });
}

MediaRoomSession _fakeRoom(_FakeMediaSession media) => MediaRoomSession.attach(
  roomCode: 'room',
  participantId: media.participantId,
  session: media,
  backend: MediaBackendClient(
    MediaBackendConfig.fromUrl(
      'http://localhost',
      heartbeatInterval: Duration.zero,
    ),
    transport: _FakeBackendTransport(),
  ),
  heartbeatInterval: Duration.zero,
);

class _FakeBackendTransport implements MediaBackendTransport {
  @override
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async =>
      const MediaBackendTransportResponse(statusCode: 200, body: '{"ok":true}');

  @override
  void close() {}
}

class _FakeProductChatSession implements ChatSession {
  final StreamController<ChatConnectionState> _states =
      StreamController<ChatConnectionState>.broadcast();
  final StreamController<List<ChatMessage>> _snapshots =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<ChatEvent> _events =
      StreamController<ChatEvent>.broadcast();

  @override
  String get providerId => 'product-chat';
  @override
  ChatRole get role => ChatRole.participant;
  @override
  ChatCapabilities get capabilities =>
      const ChatCapabilities(canSendMessage: true);
  @override
  ChatConnectionState get state => ChatConnectionState.connected;
  @override
  List<ChatMessage> get messages => const [];
  @override
  Stream<ChatConnectionState> get states => _states.stream;
  @override
  Stream<List<ChatMessage>> get messageSnapshots => _snapshots.stream;
  @override
  Stream<ChatEvent> get events => _events.stream;
  @override
  Future<void> connect(
    ChatJoinInfo joinInfo, {
    ChatCredentialProvider? credentialProvider,
  }) async {}
  @override
  Future<void> sendMessage(String message) async {}
  @override
  Future<void> deleteMessage(String messageId) async {}
  @override
  Future<void> disconnectUser(String userId) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    await _states.close();
    await _snapshots.close();
    await _events.close();
  }
}

class _FakeDataBus {
  final List<_FakeMediaSession> _sessions = <_FakeMediaSession>[];

  void register(_FakeMediaSession session) => _sessions.add(session);

  void unregister(_FakeMediaSession session) => _sessions.remove(session);

  void publishRaw({
    required _FakeMediaSession sender,
    required String message,
    required String topic,
  }) {
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    for (final session in List<_FakeMediaSession>.of(_sessions)) {
      session.receive(
        MediaMessage(
          participantId: sender.participantId,
          displayName: sender.displayName,
          message: message,
          topic: topic,
          timestampMs: timestampMs,
          providerId: sender.providerId,
        ),
      );
    }
  }
}

class _FakeMediaSession implements MediaSession, MediaDataMessenger {
  _FakeMediaSession({
    required this.participantId,
    required this.displayName,
    this.role = MediaRole.participant,
    this.canSendData = true,
    this.canReceiveData = true,
    _FakeDataBus? bus,
  }) : _bus = bus {
    _bus?.register(this);
    _snapshot = MediaSnapshot(
      state: MediaSessionState.connected,
      role: role,
      participants: [
        MediaParticipant(
          id: participantId,
          displayName: displayName,
          isLocal: true,
        ),
      ],
      localParticipantId: participantId,
      capabilities: capabilities,
    );
  }

  final String participantId;
  final String displayName;
  final bool canSendData;
  final bool canReceiveData;
  final _FakeDataBus? _bus;
  final StreamController<MediaSessionState> _states =
      StreamController<MediaSessionState>.broadcast(sync: true);
  final StreamController<MediaSnapshot> _snapshots =
      StreamController<MediaSnapshot>.broadcast(sync: true);
  final StreamController<MediaEvent> _events =
      StreamController<MediaEvent>.broadcast(sync: true);
  late MediaSnapshot _snapshot;
  bool _disposed = false;

  @override
  String get providerId => 'fake';

  @override
  final MediaRole role;

  @override
  MediaCapabilities get capabilities => MediaCapabilities(
    canSendData: canSendData,
    canReceiveData: canReceiveData,
  );

  @override
  MediaSessionState get state => _snapshot.state;

  @override
  MediaSnapshot get snapshot => _snapshot;

  @override
  Stream<MediaSessionState> get states => _states.stream;

  @override
  Stream<MediaSnapshot> get snapshots => _snapshots.stream;

  @override
  Stream<MediaEvent> get events => _events.stream;

  void setState(MediaSessionState next) {
    _snapshot = _snapshot.copyWith(state: next);
    _states.add(next);
    _snapshots.add(_snapshot);
  }

  void receive(MediaMessage message) {
    if (_disposed || !canReceiveData) return;
    _snapshot = _snapshot.copyWith(messages: [..._snapshot.messages, message]);
    _snapshots.add(_snapshot);
    _events.add(MediaMessageReceived(message));
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    if (_disposed || !canSendData) {
      throw MediaError(
        code: MediaErrorCode.unsupportedFeature,
        message: 'Data sending is disabled.',
        providerId: providerId,
      );
    }
    _bus?.publishRaw(sender: this, message: message, topic: topic);
  }

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {}

  @override
  Future<void> leave() async {
    if (!_disposed) setState(MediaSessionState.ended);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _bus?.unregister(this);
    _snapshot = _snapshot.copyWith(state: MediaSessionState.disposed);
    await _states.close();
    await _snapshots.close();
    await _events.close();
  }
}
