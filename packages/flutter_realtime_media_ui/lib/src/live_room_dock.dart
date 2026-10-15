import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'room_chat_presentation_controller.dart';
import 'room_live_chat_input.dart';

class LiveRoomDock extends StatelessWidget {
  const LiveRoomDock({
    super.key,
    required this.snapshot,
    required this.isHost,
    required this.interactive,
    required this.chatSession,
    required this.inputOpen,
    required this.chatController,
    required this.onOpenInput,
    required this.onCloseInput,
    required this.runAction,
    this.onSetCameraEnabled,
    required this.backgroundCapabilities,
    required this.backgroundEffect,
    required this.onBackground,
    required this.showGift,
    required this.onGift,
    required this.showLikes,
    required this.likeCount,
    required this.onLike,
  });
  final MediaSnapshot snapshot;
  final bool isHost;
  final InteractiveMediaSession? interactive;
  final ChatSession? chatSession;
  final bool inputOpen;
  final RoomChatPresentationController chatController;
  final VoidCallback onOpenInput;
  final VoidCallback onCloseInput;
  final Future<void> Function(Future<void> Function()) runAction;
  final Future<void> Function(bool enabled)? onSetCameraEnabled;
  final MediaBackgroundCapabilities backgroundCapabilities;
  final MediaBackgroundEffect backgroundEffect;
  final VoidCallback onBackground;
  final bool showGift;
  final VoidCallback onGift;
  final bool showLikes;
  final int likeCount;
  final VoidCallback onLike;
  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final interactive = this.interactive;
    final caps = snapshot.capabilities;
    final chatSession = this.chatSession;
    final inputOpen = this.inputOpen && chatSession != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          // Single in-place chat input (no second popup input box)
          Expanded(
            child: RoomLiveChatInput(
              controller: chatController,
              onOpen: onOpenInput,
              onClose: onCloseInput,
              chat: chatSession,
              inputOpen: inputOpen,
            ),
          ),
          const SizedBox(width: 8),

          if (isHost && interactive != null && caps.canPublishAudio) ...[
            RealtimeGlassIconButton(
              tooltip: snapshot.localMuted ? strings.unmute : strings.mute,
              icon: snapshot.localMuted
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              size: 40,
              radius: RealtimeUiTokens.pillRadius,
              danger: snapshot.localMuted,
              active: !snapshot.localMuted,
              onPressed: () => runAction(interactive.toggleMute),
            ),
            const SizedBox(width: 8),
          ],

          // Host tool: Camera Toggle
          if (isHost && interactive != null && caps.canPublishVideo) ...[
            RealtimeGlassIconButton(
              tooltip: snapshot.localVideoEnabled
                  ? strings.stopVideo
                  : strings.startVideo,
              icon: snapshot.localVideoEnabled
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              size: 40,
              radius: RealtimeUiTokens.pillRadius,
              danger: !snapshot.localVideoEnabled,
              active: snapshot.localVideoEnabled,
              onPressed: () => runAction(
                () => (onSetCameraEnabled ?? interactive.setVideoEnabled)(
                  !snapshot.localVideoEnabled,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Host tool: Switch Camera
          if (isHost &&
              interactive != null &&
              caps.canSwitchCamera &&
              snapshot.localVideoEnabled) ...[
            RealtimeGlassIconButton(
              tooltip: strings.switchCamera,
              icon: Icons.cameraswitch_rounded,
              size: 40,
              radius: RealtimeUiTokens.pillRadius,
              onPressed: () => runAction(
                () => interactive.switchCamera(MediaCameraPosition.back),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Host tool: Virtual Background / Beauty
          if (isHost && caps.canPublishVideo) ...[
            RealtimeGlassIconButton(
              tooltip: strings.virtualBackground,
              icon: Icons.auto_fix_high_rounded,
              size: 40,
              radius: RealtimeUiTokens.pillRadius,
              active: backgroundEffect.enabled,
              onPressed: onBackground,
            ),
            const SizedBox(width: 8),
          ],

          // Gift Button (Viewer & Host if custom)
          if (!isHost || showGift) ...[
            RealtimeGlassIconButton(
              tooltip: strings.sendGift,
              icon: Icons.card_giftcard_rounded,
              size: 40,
              radius: RealtimeUiTokens.pillRadius,
              onPressed: () => onGift(),
            ),
          ],

          if (showLikes) ...[
            const SizedBox(width: 8),
            // Only expose interactions backed by an actual SDK controller.
            Tooltip(
              message: '${strings.totalLikes} $likeCount',
              child: InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.pillRadius,
                ),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF2D55), Color(0xFFFF5252)],
                    ),
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2D55).withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      if (likeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$likeCount',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
