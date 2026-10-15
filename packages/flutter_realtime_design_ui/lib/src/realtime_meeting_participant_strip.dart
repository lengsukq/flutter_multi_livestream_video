part of '../flutter_realtime_design_ui.dart';

/// Scrollable participant previews shared by camera and presentation layouts.
/// [leading] can hold a separately labelled shared-content preview.
class RealtimeMeetingParticipantStrip extends StatefulWidget {
  const RealtimeMeetingParticipantStrip({
    super.key,
    this.participants = const [],
    this.onSelectParticipant,
    this.leading,
    this.height = 110,
  });

  final List<RealtimeMeetingTileData> participants;
  final ValueChanged<RealtimeMeetingTileData>? onSelectParticipant;
  final Widget? leading;
  final double height;

  @override
  State<RealtimeMeetingParticipantStrip> createState() =>
      _RealtimeMeetingParticipantStripState();
}

class _RealtimeMeetingParticipantStripState
    extends State<RealtimeMeetingParticipantStrip> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 600;
      final width = compact ? 120.0 : 156.0;
      final count =
          widget.participants.length + (widget.leading == null ? 0 : 1);
      if (count == 0) return const SizedBox.shrink();
      final contentWidth = count * width + (count - 1) * 10;
      final inset = contentWidth < constraints.maxWidth - 24
          ? (constraints.maxWidth - contentWidth) / 2
          : 12.0;
      return SizedBox(
        height: compact ? widget.height.clamp(48.0, 92.0) : widget.height,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: Scrollbar(
            controller: _scrollController,
            child: ListView.separated(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: inset, vertical: 4),
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (widget.leading != null && index == 0) {
                  return SizedBox(width: width, child: widget.leading);
                }
                final item = widget
                    .participants[index - (widget.leading == null ? 0 : 1)];
                return Semantics(
                  key: ValueKey('meeting-participant-${item.id}'),
                  button: widget.onSelectParticipant != null,
                  label: item.displayName,
                  child: _buildFilmstripTile(context, item, compact: compact),
                );
              },
            ),
          ),
        ),
      );
    },
  );

  Widget _buildFilmstripTile(
    BuildContext context,
    RealtimeMeetingTileData item, {
    required bool compact,
  }) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;
    final width = compact ? 120.0 : 156.0;

    return RealtimeGlassPressable(
      onTap: () => widget.onSelectParticipant?.call(item),
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
                  Center(
                    child: RealtimeAvatar(
                      name: item.displayName,
                      avatarUrl: item.avatarUrl,
                      size: 40,
                    ),
                  ),

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
}
