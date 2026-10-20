import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

class MeetingSharingFixture {
  MeetingSharingFixture._(this.media, this.room, this.repository);
  final SharingMedia media;
  final RealtimeRoom room;
  final SharingRepository? repository;

  static Future<MeetingSharingFixture> create({
    SharedContentMode? mode,
    bool teaching = true,
    bool localShare = false,
    bool withTrack = true,
    MediaTrackRenderer renderer = const SharingRenderer(),
    MediaCloudRecordingSession? cloudRecording,
    MediaRole role = MediaRole.participant,
    ChatSession? chat,
  }) async {
    final media = SharingMedia()..testRole = role;
    media.current = media.current.copyWith(
      localScreenShareEnabled: localShare,
      capabilities: media.current.capabilities.copyWith(canScreenShare: true),
      contentShareTrack: withTrack
          ? SharingTrack('screen', localShare ? 'self' : 'guest', screen: true)
          : null,
    );
    SharingRepository? repository;
    if (mode != null) {
      final memory = MemoryWhiteboardRepository();
      repository = SharingRepository(
        await memory.snapshot(),
        mode,
        localShare ? 'self' : 'guest',
      );
      await memory.close();
    }
    final repo = repository;
    final room = RealtimeRoom(
      media: MediaRoomSession.direct(
        roomCode: 'meeting',
        participantId: 'self',
        session: media,
      ),
      renderer: renderer,
      chat: chat,
      cloudRecordingSession: cloudRecording,
      featurePlugins: [
        if (repo != null) ...[
          if (teaching)
            ClassroomPreset(
              repositoryFactory: (_) => repo,
              enableForDirectRooms: true,
              pollInterval: const Duration(hours: 1),
            ),
          if (teaching)
            const SharedContentPreset()
          else
            SharedContentPreset(
              repositoryFactory: (_) => ClassroomSharedContentRepository(repo),
            ),
        ],
      ],
      disposeClients: () {},
    );
    await room.initialize();
    await room.sharedContent?.start();
    return MeetingSharingFixture._(media, room, repository);
  }

  Future<void> mode(SharedContentMode mode, {String? canvasId}) async {
    repository!.mode = mode;
    if (canvasId != null) repository!.canvasId = canvasId;
    repository!.revision++;
    await room.classroom!.refresh();
  }
}

class SharingTrack extends MediaVideoTrack {
  const SharingTrack(this.id, this.participantId, {this.screen = false});
  @override
  final String id;
  @override
  final String participantId;
  final bool screen;
  @override
  bool get isScreenShare => screen;
  @override
  bool get isLocal => participantId == 'self';
  @override
  int get width => 640;
  @override
  int get height => 360;
}

class SharingRenderer extends MediaTrackRenderer {
  const SharingRenderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      ColoredBox(key: ValueKey('render-${track.id}'), color: Colors.teal);
}

class SharingMedia extends InteractiveMediaSession {
  MediaRole testRole = MediaRole.participant;
  final changes = StreamController<MediaSnapshot>.broadcast();
  final eventChanges = StreamController<MediaEvent>.broadcast();
  final mutations = <String>[];
  MediaSnapshot current = MediaSnapshot(
    state: MediaSessionState.connected,
    localParticipantId: 'self',
    localVideoEnabled: true,
    capabilities: const MediaCapabilities.meeting(),
    participants: const [
      MediaParticipant(
        id: 'self',
        displayName: 'Local',
        isLocal: true,
        isVideoEnabled: true,
        videoTrack: SharingTrack('camera-self', 'self'),
      ),
      MediaParticipant(
        id: 'guest',
        displayName: 'Guest',
        isVideoEnabled: true,
        videoTrack: SharingTrack('camera-guest', 'guest'),
      ),
      MediaParticipant(id: 'off', displayName: 'Camera off'),
    ],
  );
  void emit(MediaSnapshot snapshot) {
    current = snapshot;
    changes.add(snapshot);
  }

  @override
  String get providerId => 'test';
  @override
  MediaRole get role => testRole;
  @override
  MediaCapabilities get capabilities => current.capabilities;
  @override
  MediaSessionState get state => current.state;
  @override
  MediaSnapshot get snapshot => current;
  @override
  Stream<MediaSnapshot> get snapshots => changes.stream;
  @override
  Stream<MediaSessionState> get states => const Stream.empty();
  @override
  Stream<MediaEvent> get events => eventChanges.stream;
  @override
  Future<void> join(MediaJoinInfo joinInfo) async {
    mutations.add('join');
  }

  @override
  Future<void> leave() async {
    mutations.add('leave');
  }

  @override
  Future<void> setMuted(bool muted) async {
    mutations.add('microphone');
  }

  @override
  Future<void> toggleMute() async {
    mutations.add('microphone');
  }

  @override
  Future<void> setVideoEnabled(bool enabled) async {
    mutations.add('camera');
  }

  @override
  Future<void> setScreenShareEnabled(bool enabled) async {
    mutations.add('screen');
    emit(current.copyWith(localScreenShareEnabled: enabled));
  }

  @override
  Future<void> switchCamera(MediaCameraPosition position) async {
    mutations.add('camera');
  }

  @override
  Future<List<MediaAudioDevice>> listAudioDevices() async => const [];
  @override
  Future<void> selectAudioDevice(MediaAudioDevice device) async {}
  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {}
  @override
  Future<void> dispose() async {
    await changes.close();
    await eventChanges.close();
  }
}

class SharingRepository implements ClassroomRepository {
  SharingRepository(this.whiteboard, this.mode, this.owner);
  WhiteboardState whiteboard;
  final String owner;
  SharedContentMode mode;
  String canvasId = 'screen-session-1';
  int revision = 1;
  bool annotationActive = false;
  final commands = <ClassroomCommand>[];
  @override
  Future<ClassroomState> snapshot() async {
    return ClassroomState(
      roomCode: 'meeting',
      role: ClassroomRole.teacher,
      revision: revision,
      students: const [],
      questions: const [],
      stats: const ClassroomStats(),
      tools: ClassroomToolsState(
        annotation: annotationActive
            ? AnnotationCanvas(
                canvasId: canvasId,
                sourceKey: 'screen',
                participantId: owner,
              )
            : null,
        content: SharedContentState(
          mode: mode,
          whiteboard: whiteboard,
          canManage: true,
          revision: revision,
          screen: AnnotationCanvas(canvasId: canvasId, participantId: owner),
        ),
      ),
    );
  }

  @override
  Future<ClassroomState> action(ClassroomCommand command) async {
    commands.add(command);
    throw StateError('Viewing must not issue classroom commands');
  }

  @override
  void close() {}
}
