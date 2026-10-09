import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_strings.dart';
import 'realtime_style.dart';
import 'realtime_ui_style.dart';

class MediaParticipantTile extends StatelessWidget {
  const MediaParticipantTile({
    super.key,
    required this.participant,
    required this.renderer,
    this.isFocused = false,
    this.onTap,
  });
  final MediaParticipant participant;
  final MediaTrackRenderer renderer;
  final bool isFocused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final name = participant.displayName.isEmpty
        ? strings.participant
        : participant.displayName;
    final speaking = participant.isSpeaking;

    Widget tile = AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: style.glassGradient,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        border: Border.all(
          color: speaking
              ? const Color(0xFF10B981)
              : isFocused
              ? style.primary
              : style.border,
          width: speaking || isFocused ? 2.2 : 1.1,
        ),
        boxShadow: speaking
            ? [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : style.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (participant.isVideoEnabled && participant.videoTrack != null)
              MediaTrackView(renderer: renderer, track: participant.videoTrack)
            else
              Container(
                color: style.surfaceSubtle,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: RealtimeUiTokens.animNormal,
                  padding: EdgeInsets.all(speaking ? 8 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: speaking
                        ? Border.all(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.45),
                            width: 2.5,
                          )
                        : null,
                  ),
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: style.primarySubtle,
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style: TextStyle(
                        color: style.primary,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            if (onTap != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: style.surface.withValues(
                      alpha: style.isDark ? 0.85 : 0.92,
                    ),
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                    border: Border.all(color: style.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: style.isDark ? 0.25 : 0.08,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    isFocused
                        ? Icons.grid_view_rounded
                        : Icons.open_in_full_rounded,
                    size: 13,
                    color: style.textMuted,
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: style.surface.withValues(
                    alpha: style.isDark ? 0.85 : 0.92,
                  ),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.pillRadius,
                  ),
                  border: Border.all(color: style.border),
                  boxShadow: style.cardShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name${participant.isLocal ? strings.youSuffix : ''}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: style.text,
                        ),
                      ),
                    ),
                    Icon(
                      participant.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      size: 15,
                      color: participant.isMuted
                          ? style.danger
                          : speaking
                          ? const Color(0xFF10B981)
                          : style.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      tile = RealtimeGlassPressable(
        onTap: onTap,
        pressedScale: 0.985,
        borderRadius: RealtimeUiTokens.cardRadius,
        child: tile,
      );
    }
    return tile;
  }
}
