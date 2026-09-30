import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

import 'realtime_room.dart';

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
  });

  final RealtimeRoom room;
  final MediaRoomViewConfig config;
  final Widget? header;
  final MediaParticipantBuilder? participantBuilder;
  final VoidCallback? onLeave;

  @override
  State<RealtimeRoomView> createState() => _RealtimeRoomViewState();
}

class _RealtimeRoomViewState extends State<RealtimeRoomView> {
  Future<void>? _prepareFuture;

  @override
  void initState() {
    super.initState();
    _prepareFuture = _prepare();
  }

  @override
  void didUpdateWidget(covariant RealtimeRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room) ||
        oldWidget.config.initialMediaSettings !=
            widget.config.initialMediaSettings) {
      _prepareFuture = _prepare();
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

  Widget _roomView() => MediaRoomView(
    room: widget.room.media,
    renderer: widget.room.renderer,
    backgroundEffects: widget.room,
    chatSession: widget.room.chat,
    chatModeration: widget.room.chatModeration,
    config: widget.config,
    header: widget.header,
    participantBuilder: widget.participantBuilder,
    onLeave: widget.onLeave,
  );
}
