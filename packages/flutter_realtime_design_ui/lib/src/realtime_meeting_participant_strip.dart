part of '../flutter_realtime_design_ui.dart';

/// Scrollable participant previews shared by camera and presentation layouts.
/// [leading] can hold a separately labelled shared-content preview.
class RealtimeMeetingParticipantStrip extends StatefulWidget {
  const RealtimeMeetingParticipantStrip({
    super.key,
    this.participants = const [],
    this.onSelectParticipant,
    this.leading,
    this.height = 100,
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
      final compact =
          constraints.maxWidth < RealtimeBreakpoints.compactMaxWidth;
      final width = compact ? 112.0 : 150.0;
      final count =
          widget.participants.length + (widget.leading == null ? 0 : 1);
      if (count == 0) return const SizedBox.shrink();
      final contentWidth = count * width + (count - 1) * 10;
      final inset = contentWidth < constraints.maxWidth - 24
          ? (constraints.maxWidth - contentWidth) / 2
          : 12.0;
      return SizedBox(
        height: compact ? widget.height.clamp(48.0, 88.0) : widget.height,
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
    final width = compact ? 112.0 : 150.0;
    final radius = RealtimeUiThemeExtension.of(context).controlRadius;

    return RealtimeGlassPressable(
      onTap: () => widget.onSelectParticipant?.call(item),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: item.isSpeaking ? style.speak : style.border,
            width: item.isSpeaking ? 2 : 1,
          ),
          color: style.tile,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.videoWidget ??
                  Center(
                    child: RealtimeAvatar(
                      name: item.displayName,
                      avatarUrl: item.avatarUrl,
                      size: compact ? 32 : 40,
                    ),
                  ),
              if (item.handRaised)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: style.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.pan_tool_rounded,
                      size: 13,
                      color: style.onAccent,
                    ),
                  ),
                )
              else if (item.isMuted)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C121C).withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_off_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C121C).withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.isSpeaking) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: style.speak,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
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
