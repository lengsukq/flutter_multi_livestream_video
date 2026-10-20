import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

class MediaParticipantTile extends StatelessWidget {
  const MediaParticipantTile({
    super.key,
    required this.participant,
    required this.renderer,
    this.isFocused = false,
    this.onTap,
    this.showNameTag = true,
    this.borderless = false,
    this.fit = BoxFit.contain,
  });
  final MediaParticipant participant;
  final MediaTrackRenderer renderer;
  final bool isFocused;
  final VoidCallback? onTap;
  final bool showNameTag;
  final bool borderless;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);
    final style = RealtimeStyle.of(context);
    final name = participant.displayName.isEmpty
        ? strings.participant
        : participant.displayName;
    final speaking = participant.isSpeaking;
    final radius = borderless
        ? 0.0
        : RealtimeUiThemeExtension.of(context).stageRadius;

    Widget tile = AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      decoration: borderless
          ? null
          : BoxDecoration(
              color: style.tile,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: speaking
                    ? style.speak
                    : isFocused
                    ? style.accent
                    : style.border,
                width: speaking || isFocused ? 2 : 1,
              ),
            ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (participant.isVideoEnabled && participant.videoTrack != null)
              MediaTrackView(
                renderer: renderer,
                track: participant.videoTrack,
                fit: fit,
                // Only renderers that guarantee native aspect-preserving fit
                // may fill the stage directly. Chime and raw texture/platform
                // views need the track's aspect ratio enforced externally.
                rendererManagesFit: renderer.handlesVideoFit(
                  participant.videoTrack!,
                ),
              )
            else
              ColoredBox(
                color: style.tile,
                child: Center(
                  child: AnimatedContainer(
                    duration: RealtimeUiTokens.animNormal,
                    padding: EdgeInsets.all(speaking ? 8 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: speaking
                          ? Border.all(
                              color: style.speak.withValues(alpha: 0.55),
                              width: 2.5,
                            )
                          : null,
                    ),
                    child: RealtimeAvatar(
                      name: name,
                      avatarUrl: participant.avatarUrl,
                      size: borderless ? 88 : 64,
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
                    color: style.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: style.border),
                    boxShadow: style.cardShadow,
                  ),
                  child: Icon(
                    isFocused
                        ? Icons.grid_view_rounded
                        : Icons.open_in_full_rounded,
                    size: 13,
                    color: style.textSecondary,
                  ),
                ),
              ),
            if (showNameTag)
              Positioned(
                left: 8,
                bottom: 8,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C121C).withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '$name${participant.isLocal ? strings.youSuffix : ''}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (speaking)
                          _SpeakingBars(color: style.speak)
                        else
                          Icon(
                            participant.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                      ],
                    ),
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
        borderRadius: radius,
        child: tile,
      );
    }
    return tile;
  }
}

/// Three animated bars shown next to a speaking participant.
class _SpeakingBars extends StatefulWidget {
  const _SpeakingBars({required this.color});
  final Color color;

  @override
  State<_SpeakingBars> createState() => _SpeakingBarsState();
}

class _SpeakingBarsState extends State<_SpeakingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(
        width: 14,
        height: 12,
        child: Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return SizedBox(
      width: 14,
      height: 12,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 2 ? 0 : 2),
                  child: Container(
                    height: 4 + 8 * ((i * 0.27 + _controller.value) % 1),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
