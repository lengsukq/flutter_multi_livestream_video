part of '../flutter_realtime_design_ui.dart';

/// Meeting Stage with Main Speaker Focus + Bottom Participant Filmstrip Carousel.
///
/// Directly models the Apple Studio / iPad Pro Workspace layout from Reference Image 2:
/// - Dominant focal presenter / active speaker video area with 18pt squircle corners
/// - Floating frosted glass participant name capsule and layout toggle
/// - Horizontally scrollable thumbnail strip of remote attendees
class RealtimeMeetingFilmstripStage extends StatelessWidget {
  const RealtimeMeetingFilmstripStage({
    super.key,
    required this.primaryParticipant,
    this.participants = const [],
    this.onSelectParticipant,
    this.onToggleLayout,
    this.filmstripHeight = 110.0,
    this.bottomControlsInset = 0,
  });

  final RealtimeMeetingTileData primaryParticipant;
  final List<RealtimeMeetingTileData> participants;
  final ValueChanged<RealtimeMeetingTileData>? onSelectParticipant;
  final VoidCallback? onToggleLayout;
  final double filmstripHeight;

  /// Space reserved for a floating dock beneath the filmstrip on wide stages.
  final double bottomControlsInset;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final overlayThumbnails = !compact && constraints.maxHeight >= 360;
        final overlayLabelBottom = overlayThumbnails
            ? bottomControlsInset +
                  (participants.isNotEmpty ? filmstripHeight + 22 : 14)
            : 14.0;

        final mainVideo = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              RealtimeUiThemeExtension.of(context).stageRadius,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video or Avatar Background
                ColoredBox(
                  color: isDark
                      ? RealtimeUiTokens.canvasDark
                      : const Color(0xFFE5E5EA),
                  child:
                      primaryParticipant.videoWidget ??
                      _buildAvatarFallback(context, primaryParticipant),
                ),

                // Active speaker subtle breathing border
                if (primaryParticipant.isSpeaking)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            RealtimeUiThemeExtension.of(context).stageRadius,
                          ),
                          border: Border.all(
                            color: RealtimeUiTokens.appleTeal,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Bottom-Left: Name Capsule
                Positioned(
                  left: 14,
                  bottom: overlayLabelBottom,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth - 96,
                    ),
                    child: _buildGlassNamePill(
                      primaryParticipant.displayName,
                      isMuted: primaryParticipant.isMuted,
                      isSpeaking: primaryParticipant.isSpeaking,
                    ),
                  ),
                ),

                // Bottom-Right: View Toggle / Fullscreen
                if (onToggleLayout != null &&
                    RealtimeIdleControls.controlsVisible(context))
                  Positioned(
                    right: 14,
                    bottom: overlayLabelBottom,
                    child: RealtimeGlassIconButton(
                      icon: Icons.fullscreen_rounded,
                      size: 38,
                      radius: RealtimeUiTokens.compactRadius,
                      onPressed: onToggleLayout,
                      tooltip:
                          Localizations.localeOf(context).languageCode == 'zh'
                          ? '切换布局'
                          : 'Switch layout',
                    ),
                  ),
              ],
            ),
          ),
        );
        final filmstrip = participants.isEmpty
            ? const SizedBox.shrink()
            : Container(
                height: compact ? 92 : filmstripHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: LayoutBuilder(
                  builder: (context, stripConstraints) {
                    final tileWidth = compact ? 120.0 : 156.0;
                    final contentWidth =
                        participants.length * tileWidth +
                        (participants.length - 1) * 10;
                    final inset = contentWidth < stripConstraints.maxWidth
                        ? (stripConstraints.maxWidth - contentWidth) / 2
                        : 0.0;
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: inset),
                      itemCount: participants.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => _buildFilmstripTile(
                        context,
                        participants[index],
                        compact: compact,
                      ),
                    );
                  },
                ),
              );

        // Keep the stage dominant like the reference: on roomy viewports
        // thumbnails float over the video; on phones/short windows they get
        // their own row so neither the video nor the touch targets collapse.
        if (compact || constraints.maxHeight < 360) {
          return Column(
            children: [
              Expanded(child: mainVideo),
              if (participants.isNotEmpty) filmstrip,
            ],
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            mainVideo,
            if (participants.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomControlsInset + 8,
                child: filmstrip,
              ),
          ],
        );
      },
    );
  }

  Widget _buildFilmstripTile(
    BuildContext context,
    RealtimeMeetingTileData item, {
    required bool compact,
  }) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;
    final width = compact ? 120.0 : 156.0;

    return RealtimeGlassPressable(
      borderRadius: 14,
      onTap: () => onSelectParticipant?.call(item),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            RealtimeUiThemeExtension.of(context).controlRadius,
          ),
          border: Border.all(
            color: item.isSpeaking
                ? RealtimeUiTokens.appleTeal
                : (isDark ? const Color(0x2EFFFFFF) : const Color(0x1F000000)),
            width: item.isSpeaking ? 1.8 : 0.8,
          ),
          color: isDark
              ? RealtimeUiTokens.canvasDarkElevated
              : const Color(0xFFF5F5F7),
          boxShadow: RealtimeUiTokens.iosCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.videoWidget ??
                  _buildAvatarFallback(context, item, small: true),

              // Bottom Overlay: Mute icon + Name
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.compactRadius,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            size: 13,
                            color: item.isMuted
                                ? RealtimeUiTokens.appleDanger
                                : RealtimeUiTokens.appleTeal,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassNamePill(
    String name, {
    required bool isMuted,
    required bool isSpeaking,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            border: Border.all(
              color: isSpeaking
                  ? RealtimeUiTokens.appleTeal.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.16),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSpeaking) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: RealtimeUiTokens.appleTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 14,
                color: isMuted
                    ? RealtimeUiTokens.appleDanger
                    : RealtimeUiTokens.appleTeal,
              ),
            ],
          ),
        ),
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
