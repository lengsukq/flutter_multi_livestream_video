import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

void main() {
  testWidgets('host can place the same leave widget at the top right', (
    tester,
  ) async {
    final media = _FakeMediaSession();
    final room = _room(media);
    addTearDown(room.dispose);

    for (final width in [390.0, 768.0, 1280.0, 1440.0]) {
      await tester.binding.setSurfaceSize(Size(width, 850));
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeRoomUiScope(
            room: room,
            child: Scaffold(
              body: Column(
                children: [
                  const Row(
                    children: [
                      RealtimeRoomInfo(),
                      Spacer(),
                      RealtimeLeaveButton(),
                    ],
                  ),
                  const Expanded(child: RealtimeVideoGrid()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final rect = tester.getRect(find.byType(RealtimeLeaveButton));
      expect(width - rect.right, lessThanOrEqualTo(8));
      expect(rect.top, lessThan(80));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'composable actions share room snapshots and do not own session',
    (tester) async {
      final media = _FakeMediaSession();
      final room = _room(media);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeRoomUiScope(
            room: room,
            child: const Scaffold(
              body: Column(
                children: [RealtimeMicrophoneButton(), RealtimeCameraButton()],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(RealtimeMicrophoneButton));
      await tester.pump();
      expect(media.muteCalls, 1);
      expect(media.snapshot.localMuted, false);
      await tester.tap(find.byType(RealtimeCameraButton));
      await tester.pump();
      expect(media.cameraCalls, 1);
      expect(media.snapshot.localVideoEnabled, true);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(media.disposeCalls, 0, reason: 'UI unmount must not end the call');
    },
  );

  testWidgets('broadcast stage renders the host, not audience members', (
    tester,
  ) async {
    final media = _FakeMediaSession(role: MediaRole.viewer);
    media._emit(
      media.snapshot.copyWith(
        participants: const [
          MediaParticipant(id: 'self', displayName: 'Viewer', isLocal: true),
          MediaParticipant(
            id: 'host',
            displayName: 'Broadcaster',
            isVideoEnabled: true,
          ),
          MediaParticipant(id: 'other', displayName: 'Another viewer'),
        ],
      ),
    );
    final room = _room(media);
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: const Scaffold(body: RealtimeLiveVideoStage()),
        ),
      ),
    );
    expect(find.byType(RealtimeVideoTile), findsOneWidget);
    expect(
      tester
          .widget<RealtimeVideoTile>(find.byType(RealtimeVideoTile))
          .participant
          .id,
      'host',
    );
  });

  testWidgets('chat widgets inside a media room share one chat subscription', (
    tester,
  ) async {
    final media = _FakeMediaSession();
    final chat = _FakeChatSession();
    final room = RealtimeRoom(
      media: MediaRoomSession.direct(
        roomCode: 'room-123',
        participantId: 'self',
        session: media,
      ),
      chat: chat,
      renderer: const _FakeRenderer(),
      disposeClients: () {},
    );
    addTearDown(room.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          child: const Scaffold(
            body: Column(
              children: [
                Expanded(child: RealtimeChatPanel()),
                SizedBox(height: 65, child: RealtimeChatMessageList()),
              ],
            ),
          ),
        ),
      ),
    );
    expect(chat.listeners, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(chat.listeners, 0);
    expect(
      chat.disposed,
      isFalse,
      reason: 'Removing the UI must not dispose the chat session',
    );
  });

  testWidgets('default room template is built from public components', (
    tester,
  ) async {
    final room = _room(_FakeMediaSession());
    addTearDown(room.dispose);
    for (final width in [390.0, 768.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 850));
      await tester.pumpWidget(
        MaterialApp(home: RealtimeComposableRoomTemplate(room: room)),
      );
      await tester.pump();
      expect(find.byType(RealtimeRoomUiScope), findsOneWidget);
      expect(find.byType(RealtimeVideoGrid), findsOneWidget);
      expect(find.byType(RealtimeMicrophoneButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'camera switches front/back and audio picker shows capabilities',
    (tester) async {
      final media = _FakeMediaSession();
      final room = _room(media);
      addTearDown(room.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeRoomUiScope(
            room: room,
            child: const Scaffold(
              body: Column(
                children: [
                  RealtimeSwitchCameraButton(),
                  RealtimeAudioOutputButton(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(RealtimeSwitchCameraButton));
      await tester.pump();
      await tester.tap(find.byType(RealtimeSwitchCameraButton));
      await tester.pump();
      expect(media.cameraPositions, [
        MediaCameraPosition.back,
        MediaCameraPosition.front,
      ]);
      await tester.tap(find.byType(RealtimeAudioOutputButton));
      await tester.pumpAndSettle();
      expect(find.text('Speaker'), findsOneWidget);
      expect(find.text('Selection unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

RealtimeRoom _room(_FakeMediaSession media) => RealtimeRoom(
  media: MediaRoomSession.direct(
    roomCode: 'room-123',
    participantId: 'self',
    session: media,
  ),
  renderer: const _FakeRenderer(),
  disposeClients: () {},
);

class _FakeRenderer extends MediaTrackRenderer {
  const _FakeRenderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox.expand();
}

class _FakeMediaSession extends InteractiveMediaSession {
  _FakeMediaSession({this._role = MediaRole.participant});
  final MediaRole _role;
  final _snapshots = StreamController<MediaSnapshot>.broadcast();
  final _states = StreamController<MediaSessionState>.broadcast();
  final _events = StreamController<MediaEvent>.broadcast();
  MediaSnapshot _snapshot = MediaSnapshot(
    state: MediaSessionState.connected,
    localMuted: true,
    capabilities: const MediaCapabilities.meeting(),
    participants: const [
      MediaParticipant(id: 'self', displayName: 'Local', isLocal: true),
    ],
  );
  int muteCalls = 0;
  int cameraCalls = 0;
  final cameraPositions = <MediaCameraPosition>[];
  int disposeCalls = 0;

  @override
  String get providerId => 'fake';
  @override
  MediaRole get role => _role;
  @override
  MediaCapabilities get capabilities => snapshot.capabilities;
  @override
  MediaSessionState get state => snapshot.state;
  @override
  MediaSnapshot get snapshot => _snapshot;
  @override
  Stream<MediaSessionState> get states => _states.stream;
  @override
  Stream<MediaSnapshot> get snapshots => _snapshots.stream;
  @override
  Stream<MediaEvent> get events => _events.stream;

  void _emit(MediaSnapshot snapshot) {
    _snapshot = snapshot;
    _snapshots.add(snapshot);
  }

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {}
  @override
  Future<void> leave() async {}
  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _snapshots.close();
    await _states.close();
    await _events.close();
  }

  @override
  Future<void> setMuted(bool muted) async {
    muteCalls++;
    _emit(snapshot.copyWith(localMuted: muted));
  }

  @override
  Future<void> toggleMute() => setMuted(!snapshot.localMuted);
  @override
  Future<void> setVideoEnabled(bool enabled) async {
    cameraCalls++;
    _emit(snapshot.copyWith(localVideoEnabled: enabled));
  }

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    _emit(snapshot.copyWith(localScreenShareEnabled: enabled));
  }

  @override
  Future<void> switchCamera(MediaCameraPosition position) async =>
      cameraPositions.add(position);
  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async => const [
    MediaAudioDevice(label: 'Speaker', type: MediaAudioDeviceType.speaker),
  ];
  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) async {}
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {}
}

class _FakeChatSession extends Fake implements ChatSession {
  final _snapshots = StreamController<List<ChatMessage>>.broadcast();
  int listeners = 0;
  bool disposed = false;

  @override
  String get providerId => 'fake';
  @override
  ChatRole get role => ChatRole.participant;
  @override
  ChatConnectionState get state => ChatConnectionState.connected;
  @override
  ChatCapabilities get capabilities =>
      const ChatCapabilities(canSendMessage: true);
  @override
  List<ChatMessage> get messages => const [];
  @override
  Stream<List<ChatMessage>> get messageSnapshots => Stream.multi((controller) {
    listeners++;
    final subscription = _snapshots.stream.listen(controller.add);
    controller.onCancel = () async {
      listeners--;
      await subscription.cancel();
    };
  }, isBroadcast: true);
  @override
  Stream<ChatConnectionState> get states => const Stream.empty();
  @override
  Stream<ChatEvent> get events => const Stream.empty();
  @override
  Future<void> sendMessage(String message) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> dispose() async {
    disposed = true;
    await _snapshots.close();
  }
}
