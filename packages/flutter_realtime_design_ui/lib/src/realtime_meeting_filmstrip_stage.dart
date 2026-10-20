part of '../flutter_realtime_design_ui.dart';

/// Room stage: focused participant over a horizontally scrolling thumbnail
/// strip. Mirrors the reference classroom workspace: one dominant video, a
/// compact strip of everyone else and a soft bordered stage.
class RealtimeMeetingFilmstripStage extends StatelessWidget {
  const RealtimeMeetingFilmstripStage({
    super.key,
    required this.primaryParticipant,
    this.participants = const [],
    this.onSelectParticipant,
    this.onToggleLayout,
    this.filmstripHeight = 100.0,
    this.bottomControlsInset = 0,
    this.showFilmstrip = true,
  });

  final RealtimeMeetingTileData primaryParticipant;
  final List<RealtimeMeetingTileData> participants;
  final ValueChanged<RealtimeMeetingTileData>? onSelectParticipant;
  final VoidCallback? onToggleLayout;
  final double filmstripHeight;
  final bool showFilmstrip;

  /// Space reserved for a floating dock beneath the filmstrip on wide stages.
  final double bottomControlsInset;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < RealtimeBreakpoints.compactMaxWidth;
        final hasFilmstrip = showFilmstrip && participants.isNotEmpty;
        final mainVideo = Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              RealtimeUiThemeExtension.of(context).stageRadius,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: style.tile,
                borderRadius: BorderRadius.circular(
                  RealtimeUiThemeExtension.of(context).stageRadius,
                ),
                border: Border.all(
                  color: primaryParticipant.isSpeaking
                      ? style.speak
                      : style.border,
                  width: primaryParticipant.isSpeaking ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  RealtimeUiThemeExtension.of(context).stageRadius,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    primaryParticipant.videoWidget ??
                        ColoredBox(
                          color: style.tile,
                          child: _buildAvatarFallback(
                            context,
                            primaryParticipant,
                          ),
                        ),
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth - 88,
                        ),
                        child: _buildNamePill(
                          context,
                          primaryParticipant.displayName,
                          isMuted: primaryParticipant.isMuted,
                          isSpeaking: primaryParticipant.isSpeaking,
                        ),
                      ),
                    ),
                    if (onToggleLayout != null &&
                        RealtimeIdleControls.controlsVisible(context))
                      Positioned(
                        right: 12,
                        bottom: 10,
                        child: RealtimeGlassIconButton(
                          icon: Icons.fullscreen_rounded,
                          size: 36,
                          onPressed: onToggleLayout,
                          tooltip:
                              Localizations.localeOf(context).languageCode ==
                                  'zh'
                              ? '切换布局'
                              : 'Switch layout',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final filmstrip = RealtimeMeetingParticipantStrip(
          participants: participants,
          onSelectParticipant: onSelectParticipant,
          height: filmstripHeight,
        );

        return Padding(
          padding: EdgeInsets.only(bottom: bottomControlsInset),
          child: Column(
            children: [
              Expanded(child: mainVideo),
              if (hasFilmstrip)
                SizedBox(
                  height: constraints.maxHeight < 300 ? 64 : filmstripHeight,
                  child: filmstrip,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNamePill(
    BuildContext context,
    String name, {
    required bool isMuted,
    required bool isSpeaking,
  }) {
    final style = RealtimeStyle.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0C121C).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSpeaking
              ? style.speak.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            size: 12,
            color: isMuted
                ? const Color(0xFFFF8A8A)
                : (isSpeaking ? style.speak : Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(
    BuildContext context,
    RealtimeMeetingTileData item, {
    bool small = false,
  }) {
    return Center(
      child: RealtimeAvatar(
        name: item.displayName,
        avatarUrl: item.avatarUrl,
        size: small ? 40 : 84,
      ),
    );
  }
}
