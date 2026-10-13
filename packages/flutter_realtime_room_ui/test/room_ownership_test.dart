import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remounting a borrowed controller never closes its room', (
    tester,
  ) async {
    final media = _FakeMediaSession(role: MediaRole.participant);
    final room = RealtimeRoom(
      media: MediaRoomSession.direct(
        roomCode: 'room',
        participantId: 'self',
        session: media,
      ),
      renderer: const _FakeRenderer(),
      disposeClients: () {},
    );
    await tester.runAsync(room.initialize);
    final controller = RealtimeRoomUiController(room);
    for (var mount = 0; mount < 2; mount++) {
      await tester.pumpWidget(
        MaterialApp(
          home: RealtimeRoomUiScope(
            room: room,
            controller: controller,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      expect(controller.isDisposed, isFalse);
      expect(media.disposeCalls, 0);
    }
    final closing = controller.close();
    expect(identical(closing, controller.close()), isTrue);
    await closing;
    expect(media.disposeCalls, 0);
    await tester.runAsync(room.dispose);
    expect(media.disposeCalls, 1);
  });
  testWidgets('the host receives action failure without a forced error popup', (
    tester,
  ) async {
    final media = _FakeMediaSession(role: MediaRole.participant);
    final room = RealtimeRoom(
      media: MediaRoomSession.direct(
        roomCode: 'room',
        participantId: 'self',
        session: media,
      ),
      renderer: const _FakeRenderer(),
      disposeClients: () {},
    );
    await tester.runAsync(room.initialize);
    final failures = <RealtimeException>[];
    final controller = RealtimeRoomUiController(
      room,
      onActionError: failures.add,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RealtimeRoomUiScope(
          room: room,
          controller: controller,
          child: const Scaffold(
            body: RealtimeMediaActionButton(
              action: RealtimeRoomUiAction.microphone,
              label: 'Microphone',
              icon: Icons.mic,
            ),
          ),
        ),
      ),
    );
    media.failMute = true;
    await tester.tap(find.text('Microphone'));
    await tester.pump();
    expect(failures, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
    expect(controller.isPending(RealtimeRoomUiAction.microphone), isFalse);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
    await tester.runAsync(room.dispose);
  });
}

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
  bool failMute = false;
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
    _states.add(snapshot.state);
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
    if (failMute) throw StateError('test.failure');
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
