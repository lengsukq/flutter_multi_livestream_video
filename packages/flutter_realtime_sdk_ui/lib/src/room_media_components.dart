import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';

import 'room_ui_controller.dart';

/// Entire remote/local shared frame with contain fit, independently positioned.
class RealtimeScreenShareStage extends StatelessWidget {
  const RealtimeScreenShareStage({
    super.key,
    this.placeholder,
    this.showBar = true,
  });
  final Widget? placeholder;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final zh = RealtimeStrings.of(context).isZh;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final track = controller.snapshot.contentShareTrack;
        final trackView = MediaTrackView(
          renderer: controller.room.renderer,
          track: track,
          fit: BoxFit.contain,
          placeholder: placeholder,
        );
        if (!showBar || track == null) return trackView;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: SharedContentStageBar(
                title: zh ? '屏幕共享' : 'Screen Share',
                badgeIcon: Icons.screen_share_outlined,
                subtitle: track.isLocal
                    ? (zh ? '您正在共享屏幕' : 'You are sharing screen')
                    : (zh ? '正在查看共享画面' : 'Viewing shared screen'),
                onStop: track.isLocal ? controller.toggleScreenShare : null,
              ),
            ),
            Expanded(child: trackView),
          ],
        );
      },
    );
  }
}
