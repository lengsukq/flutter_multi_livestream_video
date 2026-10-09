import 'dart:async';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_live_ui/flutter_realtime_live_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_classroom_ui/flutter_realtime_classroom_ui.dart';

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
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('无法启动摄像头背景处理'),
                Text(snapshot.error.toString()),
                TextButton(
                  onPressed: widget.onLeave,
                  child: const Text('退出房间'),
                ),
              ],
            ),
          );
        }
        return _roomView();
      },
    );
  }

  Widget? _contentStage(BuildContext context, MediaSnapshot snapshot) {
    final controller = widget.room.sharedContent;
    final content = controller?.content;
    if (content == null || content.mode == SharedContentMode.members) {
      return null;
    }
    final candidate = snapshot.contentShareTrack;
    final track =
        candidate?.contentOwnerParticipantId == content.screen.participantId
        ? candidate
        : null;
    return SharedContentStage(
      mode: content.mode,
      whiteboard: controller!.whiteboard,
      screen: track == null
          ? null
          : MediaTrackView(
              renderer: widget.room.renderer,
              track: track,
              fit: BoxFit.contain,
            ),
      screenAspectRatio: track?.aspectRatio ?? 16 / 9,
      screenAnnotations: widget.showAnnotations
          ? controller.screenAnnotations
          : null,
      canAnnotateScreen: content.canManage && track?.isLocal == true,
    );
  }

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

class _ContentControls extends StatefulWidget {
  const _ContentControls({required this.controller});
  final SharedContentController controller;
  @override
  State<_ContentControls> createState() => _ContentControlsState();
}

class _ContentControlsState extends State<_ContentControls> {
  SharedContentController get controller => widget.controller;
  late final Future<SystemAnnotationCapabilities> _systemCapabilities =
      SystemScreenAnnotationController.capabilities();
  Future<void> _system() async {
    if (controller.systemAnnotations.active) {
      await controller.stopSystemAnnotations();
      return;
    }
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final caps = await _systemCapabilities;
    if (!mounted) return;
    final accepted =
        caps.permissionRequired ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(zh ? '跨应用标注' : 'Draw across apps'),
                content: Text(
                  zh
                      ? '工具会悬浮在主屏幕上。请确认当前共享的是整个主屏幕，以便对方看到正确位置的笔迹。选择“操作”可继续点击其他应用。'
                      : 'Tools float on your primary display. Share that entire display so viewers see aligned marks. Choose Move to interact with other apps.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(zh ? '取消' : 'Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(zh ? '打开工具' : 'Open tools'),
                  ),
                ],
              ),
            ) ==
            true;
    if (accepted != true || !mounted) return;
    try {
      await controller.startSystemAnnotations(languageCode: zh ? 'zh' : 'en');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _select(SharedContentMode mode) async {
    try {
      await controller.selectMode(mode);
    } catch (_) {
      /* shown in status */
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<SharedContentStatus>(
    stream: controller.statuses,
    initialData: controller.status,
    builder: (context, snapshot) {
      final status = snapshot.data!;
      final teacher = status.content?.canManage == true;
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      return FutureBuilder<SystemAnnotationCapabilities>(
        future: _systemCapabilities,
        builder: (context, caps) => PopupMenuButton<String>(
          enabled: !status.busy && teacher,
          tooltip: zh ? '课堂内容' : 'Class content',
          onSelected: (value) {
            if (value == 'system') {
              unawaited(_system());
            } else {
              unawaited(_select(SharedContentMode.values.byName(value)));
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: SharedContentMode.members.name,
              child: Text(zh ? '成员画面 / 停止共享' : 'Members / stop sharing'),
            ),
            PopupMenuItem(
              value: SharedContentMode.whiteboard.name,
              child: Text(zh ? '白板' : 'Whiteboard'),
            ),
            PopupMenuItem(
              value: SharedContentMode.screen.name,
              enabled: controller.canShare,
              child: Text(zh ? '屏幕共享' : 'Share screen'),
            ),
            PopupMenuItem(
              value: 'system',
              enabled:
                  status.captureActive &&
                  status.content?.mode == SharedContentMode.screen &&
                  caps.data?.supported == true,
              child: Text(
                controller.systemAnnotations.active
                    ? (zh ? '关闭悬浮标注工具' : 'Close floating annotation tools')
                    : caps.data?.supported == false
                    ? (zh ? '跨应用标注（当前系统不可用）' : 'Draw across apps (unavailable)')
                    : (zh ? '跨应用标注' : 'Draw across apps'),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status.busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    status.content?.mode == SharedContentMode.whiteboard
                        ? Icons.draw_outlined
                        : Icons.present_to_all,
                  ),
                const SizedBox(width: 4),
                Text(zh ? '课堂内容' : 'Content'),
                if (status.error != null)
                  IconButton(
                    tooltip: '${status.error}',
                    icon: const Icon(Icons.error_outline),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(zh ? '内容切换失败' : 'Content change failed'),
                        content: Text('${status.error}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (status.captureActive &&
                    status.content?.mode != SharedContentMode.screen)
                  Text(zh ? '共享仍在进行' : 'Capture active'),
              ],
            ),
          ),
        ),
      );
    },
  );
}
