import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';

class LiveRoomHeader extends StatelessWidget {
  const LiveRoomHeader({
    super.key,
    required this.snapshot,
    required this.isHost,
    required this.roomCode,
    required this.videoFit,
    required this.onVideoFitToggle,
    required this.onCleanScreen,
    required this.onLeave,
  });
  final MediaSnapshot snapshot;
  final bool isHost;
  final String roomCode;
  final BoxFit videoFit;
  final VoidCallback onVideoFitToggle;
  final VoidCallback onCleanScreen;
  final VoidCallback onLeave;
  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final viewerCount = snapshot.participants.length;
    final style = RealtimeStyle.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Anchor capsule: Avatar + LIVE pill + Room code
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: style.isDark
                  ? Colors.black.withValues(alpha: 0.65)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
              border: Border.all(
                color: style.isDark
                    ? Colors.white.withValues(alpha: 0.20)
                    : style.border,
                width: 1,
              ),
              boxShadow: style.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Anchor avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFF43F5E), Color(0xFFFB923C)],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          strings.liveStatus,
                          style: const TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.liveStream,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: style.text,
                      ),
                    ),
                    Text(
                      roomCode,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: style.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Viewers online count pill
          RealtimePill(
            label: strings.viewingCount(viewerCount),
            icon: Icons.visibility_rounded,
            foreground: style.text,
            background: style.isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.92),
            borderColor: style.isDark
                ? Colors.white.withValues(alpha: 0.20)
                : style.border,
          ),

          const Spacer(),

          RealtimeGlassIconButton(
            tooltip: videoFit == BoxFit.contain
                ? strings.fillLiveScreen
                : strings.showFullVideo,
            icon: videoFit == BoxFit.contain
                ? Icons.crop_free_rounded
                : Icons.fit_screen_rounded,
            active: videoFit == BoxFit.cover,
            size: 36,
            radius: RealtimeUiTokens.pillRadius,
            onPressed: onVideoFitToggle,
          ),

          const SizedBox(width: 8),

          // Clean Screen button
          RealtimeGlassIconButton(
            tooltip: strings.cleanScreen,
            icon: Icons.fullscreen_rounded,
            size: 36,
            radius: RealtimeUiTokens.pillRadius,
            onPressed: onCleanScreen,
          ),

          const SizedBox(width: 8),

          // Close button
          RealtimeGlassIconButton(
            tooltip: isHost ? strings.endBroadcast : strings.leaveLiveRoom,
            icon: Icons.close_rounded,
            size: 36,
            radius: RealtimeUiTokens.pillRadius,
            danger: isHost,
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

/// Floating semi-transparent chat comments stream in livestream.
