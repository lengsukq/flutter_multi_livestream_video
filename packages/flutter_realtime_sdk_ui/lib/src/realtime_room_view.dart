import 'dart:async';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'package:flutter_realtime_classroom_preset/flutter_realtime_classroom_preset.dart';
import 'package:flutter_realtime_live_ui/flutter_realtime_live_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_classroom_ui/flutter_realtime_classroom_ui.dart';
import 'room_classroom_components.dart';

part 'legacy_room_content_controls.dart';

/// Recommended ready-to-use UI for a fully resolved [RealtimeRoom].
///
/// When initial media settings are present this wrapper prepares the SDK-owned
/// processed-video source before the lower-level room UI can publish camera
/// video. Applications using [RealtimeRoomView] therefore do not need platform
/// or provider branches for virtual backgrounds.
class RealtimeRoomView extends StatefulWidget {
  const RealtimeRoomView({
    super.key,
    required this.room,
    this.config = const MediaRoomViewConfig(),
    this.header,
    this.participantBuilder,
    this.onLeave,
    this.showClassroom = true,
    this.showLiveInteractions = true,
    this.showAnnotations = true,
  });

  final RealtimeRoom room;
  final MediaRoomViewConfig config;
  final Widget? header;
  final MediaParticipantBuilder? participantBuilder;
  final VoidCallback? onLeave;
  final bool showClassroom;
  final bool showLiveInteractions;
  final bool showAnnotations;

  @override
  State<RealtimeRoomView> createState() => _RealtimeRoomViewState();
}

class _RealtimeRoomViewState extends State<RealtimeRoomView> {
  Future<void>? _prepareFuture;
  LiveInteractionSession? _likesSession;
  LiveLikesController? _likesAdapter;

  LiveLikesController? get _liveLikes {
    final session = widget.showLiveInteractions
        ? widget.room.liveInteractions
        : null;
    if (!identical(session, _likesSession)) {
      _likesSession = session;
      _likesAdapter = session == null ? null : _LiveLikesAdapter(session);
    }
    return _likesAdapter;
  }

  @override
  void initState() {
    super.initState();
    _prepareFuture = _prepare();
    unawaited(widget.room.sharedContent?.start() ?? Future.value());
  }

  @override
  void didUpdateWidget(covariant RealtimeRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.config.initialMediaSettings !=
            widget.config.initialMediaSettings) {
      _prepareFuture = _prepare();
      unawaited(widget.room.sharedContent?.start() ?? Future.value());
    }
  }

  Future<void> _prepare() async {
    final settings = widget.config.initialMediaSettings;
    if (settings == null) return;
    await widget.room.prepareVideoEffects(settings);
  }

  @override
  Widget build(BuildContext context) {
    final future = _prepareFuture;
    if (future == null) return _roomView();
    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          final style = RealtimeStyle.of(context);
          return ColoredBox(
            color: style.background,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final strings = RealtimeStrings.of(context);
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.isZh
                      ? '无法启动摄像头背景处理'
                      : 'Failed to initialize camera background effect',
                ),
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: widget.onLeave,
                  child: Text(strings.leave),
                ),
              ],
            ),
          );
        }
        return _roomView();
      },
    );
  }

  Widget? _contentStage(BuildContext context, MediaSnapshot snapshot) =>
      buildRoomSharedContentStage(
        widget.room,
        snapshot,
        withAnnotations: widget.showAnnotations,
      );

  Widget _roomView() => Stack(
    children: [
      Positioned.fill(
        child: MediaRoomView(
          room: widget.room.media,
          renderer: widget.room.renderer,
          backgroundEffects: widget.room,
          chatSession: widget.room.chat,
          chatModeration: widget.room.chatModeration,
          liveLikes: _liveLikes,
          canEnableMicrophone: widget.room.classroom == null
              ? null
              : () {
                  final classroom = widget.room.classroom!;
                  final state = classroom.state;
                  if (state?.isTeacher == true) return true;
                  // Backend-provisioned Meeting owner can still use their mic
                  // before the initial classroom snapshot is loaded.
                  if (widget.room.media.roomOwnerCredential != null) {
                    return true;
                  }
                  if (state == null) return false;
                  return state.students.any(
                    (student) =>
                        student.userId == state.selfUserId && student.canSpeak,
                  );
                },
          microphonePermissionUpdates: widget.room.classroom?.states
              .map<Object?>((_) => null),
          contentStageBuilder: widget.showClassroom ? _contentStage : null,
          contentStageUpdates: widget.showClassroom
              ? widget.room.sharedContent?.stageUpdates
              : null,
          contentControlsBuilder: widget.showClassroom
              ? (context) =>
                    (widget.room.sharedContent != null &&
                        (widget.room.sharedContent!.supported ||
                            widget.room.classroom?.state == null))
                    ? _ContentControls(controller: widget.room.sharedContent!)
                    : null
              : null,
          screenShareOverlayBuilder:
              widget.showAnnotations && widget.room.classroom != null
              ? (context, track) => ClassroomAnnotationOverlay(
                  key: ValueKey(track.id),
                  session: widget.room.classroom!.annotations,
                  participantId: track.contentOwnerParticipantId,
                  localShare: track.isLocal,
                )
              : null,
          extraControlsBuilder: (context) {
            final showLabels = MediaQuery.sizeOf(context).width >= 760;
            final extras = <Widget>[];
            if (widget.showClassroom && widget.room.classroom != null) {
              extras.add(
                ClassroomControlButton(
                  key: ObjectKey(widget.room.classroom),
                  classroom: widget.room.classroom!,
                  showLabel: showLabels,
                ),
              );
            }
            if (widget.showLiveInteractions &&
                widget.room.liveInteractions != null) {
              extras.add(
                LiveGiftControlButton(
                  key: ObjectKey(widget.room.liveInteractions),
                  session: widget.room.liveInteractions!,
                  showLabel: showLabels,
                ),
              );
            }
            return extras;
          },
          liveGiftPanelOpener:
              widget.showLiveInteractions &&
                  widget.room.liveInteractions != null
              ? (context) => showLiveGiftsBottomSheet(
                  context,
                  session: widget.room.liveInteractions!,
                )
              : null,
          config: widget.config,
          header: widget.header,
          participantBuilder: widget.participantBuilder,
          onLeave: widget.onLeave,
        ),
      ),
      if (widget.showLiveInteractions && widget.room.liveInteractions != null)
        Positioned(
          right: 16,
          bottom: 96,
          child: IgnorePointer(
            child: LiveGiftBanner(
              key: ObjectKey(widget.room.liveInteractions),
              session: widget.room.liveInteractions!,
            ),
          ),
        ),
    ],
  );
}

/// Connects the shared live-interaction state to the reusable lower-level UI.
class _LiveLikesAdapter implements LiveLikesController {
  const _LiveLikesAdapter(this.session);
  final LiveInteractionSession session;

  @override
  int get totalLikes => session.state?.totalLikes ?? 0;
  @override
  Stream<int> get totals => session.states.map((state) => state.totalLikes);
  @override
  Stream<int> get receivedLikes => session.likes.map((event) => event.quantity);
  @override
  Future<void> sendLike() => session.sendLike();
}
