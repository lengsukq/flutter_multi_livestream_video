import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';

class MeetingRoomDock extends StatelessWidget {
  const MeetingRoomDock({
    super.key,
    required this.snapshot,
    required this.compact,
    required this.interactive,
    required this.canEnableMicrophone,
    required this.runAction,
    required this.contentControls,
    required this.extraControls,
    required this.participantsOpen,
    required this.onParticipants,
    required this.showChat,
    required this.chatOpen,
    required this.unreadChatCount,
    required this.onChat,
    required this.onMore,
    required this.onLeave,
  });
  final MediaSnapshot snapshot;
  final bool compact;
  final InteractiveMediaSession? interactive;
  final bool Function()? canEnableMicrophone;
  final Future<void> Function(Future<void> Function()) runAction;
  final Widget? contentControls;
  final List<Widget> extraControls;
  final bool participantsOpen;
  final VoidCallback onParticipants;
  final bool showChat;
  final bool chatOpen;
  final int unreadChatCount;
  final VoidCallback onChat;
  final VoidCallback onMore;
  final VoidCallback onLeave;
  @override
  Widget build(BuildContext context) {
    final interactive = this.interactive;
    final caps = snapshot.capabilities;
    final strings = RealtimeStrings.of(context);
    final items = <Widget>[];

    // 1. Microphone
    if (interactive != null && caps.canPublishAudio) {
      items.add(
        _MeetingDockAction(
          icon: snapshot.localMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: snapshot.localMuted ? strings.unmute : strings.microphone,
          isActive: !snapshot.localMuted,
          isAlert: snapshot.localMuted,
          onTap: () {
            if (snapshot.localMuted && canEnableMicrophone?.call() == false) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.awaitPermissionToSpeak)),
              );
              return;
            }
            observeDetached(runAction(interactive.toggleMute));
          },
        ),
      );
    }

    // 2. Camera
    if (interactive != null && caps.canPublishVideo) {
      items.add(
        _MeetingDockAction(
          icon: snapshot.localVideoEnabled
              ? Icons.videocam_rounded
              : Icons.videocam_off_rounded,
          label: snapshot.localVideoEnabled
              ? strings.stopVideo
              : strings.startVideo,
          isActive: snapshot.localVideoEnabled,
          isAlert: !snapshot.localVideoEnabled,
          onTap: () => runAction(
            () => interactive.setVideoEnabled(!snapshot.localVideoEnabled),
          ),
        ),
      );
    }

    // 3. Screen Share
    final contentControls = this.contentControls;
    if (contentControls != null) {
      items.add(contentControls);
    } else if (interactive != null && caps.canScreenShare) {
      items.add(
        _MeetingDockAction(
          icon: snapshot.localScreenShareEnabled
              ? Icons.stop_screen_share_rounded
              : Icons.screen_share_rounded,
          label: strings.screenShare,
          isActive: snapshot.localScreenShareEnabled,
          highlightColor: const Color(0xFF10B981),
          onTap: () => runAction(
            () => interactive.setScreenShareEnabled(
              !snapshot.localScreenShareEnabled,
            ),
          ),
        ),
      );
    }

    // Extra controls from extensions
    final extraControls = this.extraControls;
    if (extraControls.isNotEmpty) {
      items.addAll(extraControls);
    }

    // 4. Participants
    items.add(
      _MeetingDockAction(
        icon: Icons.people_alt_rounded,
        label: strings.participants,
        isActive: participantsOpen,
        badgeCount: snapshot.participants.length,
        onTap: onParticipants,
      ),
    );

    // 5. Chat
    if (showChat) {
      items.add(
        _MeetingDockAction(
          icon: Icons.chat_bubble_rounded,
          label: strings.chat,
          isActive: chatOpen,
          badgeCount: unreadChatCount,
          onTap: onChat,
        ),
      );
    }

    // 6. More Settings (Virtual background, camera switch, rtc data)
    items.add(
      _MeetingDockAction(
        icon: Icons.more_horiz_rounded,
        label: strings.more,
        onTap: () => onMore(),
      ),
    );

    // 7. Leave Meeting
    items.add(
      _MeetingDockAction(
        icon: Icons.call_end_rounded,
        label: strings.leave,
        isDanger: true,
        onTap: onLeave,
      ),
    );

    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      radius: RealtimeUiTokens.dockRadius,
      opacity: .94,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}

/// Meeting dock action item with vertical icon + label layout.
class _MeetingDockAction extends StatelessWidget {
  const _MeetingDockAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isAlert = false,
    this.isDanger = false,
    this.highlightColor,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isAlert;
  final bool isDanger;
  final Color? highlightColor;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;
    final effectiveColor = isDanger
        ? const Color(0xFFEF4444)
        : isAlert
        ? const Color(0xFFEF4444)
        : highlightColor ??
              (isActive
                  ? (isDark ? const Color(0xFF818CF8) : style.primary)
                  : style.text);

    final effectiveBackground = isDanger
        ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.22 : 0.12)
        : isActive
        ? (highlightColor ?? style.primary).withValues(
            alpha: isDark ? 0.25 : 0.12,
          )
        : isDark
        ? Colors.white.withValues(alpha: 0.12)
        : style.surfaceSubtle;

    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: effectiveBackground,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.controlRadius,
                        ),
                        border: Border.all(
                          color: isActive || isDanger
                              ? effectiveColor.withValues(alpha: 0.45)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.16)
                                    : Colors.transparent),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, size: 20, color: effectiveColor),
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(
                              RealtimeUiTokens.pillRadius,
                            ),
                            border: Border.all(
                              color: style.surface,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            '$badgeCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDanger ? const Color(0xFFEF4444) : style.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
