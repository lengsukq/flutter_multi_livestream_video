import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart'
    show MediaRole;
import 'package:flutter_realtime_room_ui/flutter_realtime_room_ui.dart'
    show RealtimeRoomUiAction;

import 'realtime_room_action_button.dart';
import 'room_ui_controller.dart';

/// Reachable broadcast controls that retain the shared action lifecycle.
class RealtimeLiveMediaControls extends StatelessWidget {
  const RealtimeLiveMediaControls({super.key, this.onOpenHostTools});

  final VoidCallback? onOpenHostTools;

  @override
  Widget build(BuildContext context) {
    final controller = RealtimeRoomUiScope.of(context);
    final strings = RealtimeStrings.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.room.media.role == MediaRole.viewer) {
          return const SizedBox.shrink();
        }
        return RealtimeGlassSurface(
          radius: RealtimeUiTokens.pillRadius,
          fillColor: RealtimeUiTokens.canvasDarkElevated,
          opacity: .76,
          borderColor: Colors.white.withValues(alpha: .22),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mediaAction(context, RealtimeRoomUiAction.microphone),
              _mediaAction(context, RealtimeRoomUiAction.camera),
              if (onOpenHostTools != null) ...[
                const SizedBox(
                  height: 22,
                  child: VerticalDivider(width: 16, color: Colors.white24),
                ),
                IconButton(
                  tooltip: strings.isZh ? '主播工具' : 'Host tools',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onOpenHostTools,
                  icon: const Icon(Icons.tune_rounded, size: 21),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _mediaAction(BuildContext context, RealtimeRoomUiAction action) {
    final isZh = RealtimeStrings.of(context).isZh;
    final microphone = action == RealtimeRoomUiAction.microphone;
    return RealtimeRoomActionButton(
      action: action,
      builder: (context, onPressed, active, pending) {
        final label = microphone
            ? (isZh
                  ? (active ? '关闭麦克风' : '打开麦克风')
                  : (active ? 'Turn off microphone' : 'Turn on microphone'))
            : (isZh
                  ? (active ? '关闭摄像头' : '打开摄像头')
                  : (active ? 'Turn off camera' : 'Turn on camera'));
        return Semantics(
          toggled: active,
          child: IconButton(
            tooltip: label,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white38,
              backgroundColor: active
                  ? Colors.white.withValues(alpha: .16)
                  : null,
            ),
            onPressed: onPressed,
            icon: pending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    microphone
                        ? (active ? Icons.mic_rounded : Icons.mic_off_rounded)
                        : (active
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded),
                    size: 22,
                  ),
          ),
        );
      },
    );
  }
}
