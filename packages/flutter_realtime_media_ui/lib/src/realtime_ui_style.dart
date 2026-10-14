import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'realtime_strings.dart';

export 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';

class RealtimeModeSelector extends StatelessWidget {
  const RealtimeModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  final MediaRoomMode selectedMode;
  final ValueChanged<MediaRoomMode>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: _ModeOptionCard(
              mode: MediaRoomMode.meeting,
              title: RealtimeStrings.of(context).meeting,
              subtitle: RealtimeStrings.of(context).meetingModeSubtitle,
              icon: Icons.groups_2_rounded,
              selected: selectedMode == MediaRoomMode.meeting,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(MediaRoomMode.meeting),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeOptionCard(
              mode: MediaRoomMode.broadcast,
              title: RealtimeStrings.of(context).live,
              subtitle: RealtimeStrings.of(context).liveModeSubtitle,
              icon: Icons.podcasts_rounded,
              selected: selectedMode == MediaRoomMode.broadcast,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(MediaRoomMode.broadcast),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: RealtimeUiTokens.animFast,
        child: Text(
          selectedMode == MediaRoomMode.meeting
              ? RealtimeStrings.of(context).meetingModeDescription
              : RealtimeStrings.of(context).liveModeDescription,
          key: ValueKey(selectedMode),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: RealtimeUiTokens.textMuted,
          ),
        ),
      ),
    ],
  );
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final MediaRoomMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassPressable(
      onTap: onTap,
      borderRadius: RealtimeUiTokens.controlRadius,
      child: AnimatedContainer(
        duration: RealtimeUiTokens.animNormal,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? style.primarySubtle : style.surfaceSubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          border: Border.all(
            color: selected ? style.primary : style.border,
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: style.primary.withValues(
                      alpha: style.isDark ? 0.25 : 0.12,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: RealtimeUiTokens.animNormal,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? style.primary
                    : (style.isDark ? style.surface : style.surfaceSubtle),
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.compactRadius,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : style.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? style.primary : style.text,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: RealtimeStyle.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RealtimeRoomCard extends StatelessWidget {
  const RealtimeRoomCard({super.key, required this.room, required this.onJoin});

  final MediaRoomSummary room;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isBroadcast = room.roomMode == MediaRoomMode.broadcast;
    final strings = RealtimeStrings.of(context);
    final modeLabel = isBroadcast ? strings.live : strings.meeting;
    final icon = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.surfaceSubtle,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
        border: Border.all(color: style.border),
      ),
      child: Icon(
        isBroadcast ? Icons.podcasts_rounded : Icons.groups_2_rounded,
        size: 22,
        color: style.text,
      ),
    );
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          room.roomCode,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          strings.roomCardSummary(modeLabel, room.attendeeCount),
          softWrap: true,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final join = FilledButton(
      onPressed: onJoin,
      child: Text(isBroadcast ? strings.watchLive : strings.join),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions =
            constraints.maxWidth < 440 ||
            MediaQuery.textScalerOf(context).scale(17) >= 28;
        return RealtimeCardSurface(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          radius: RealtimeUiTokens.cardRadius,
          onTap: onJoin,
          child: stackActions
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 12),
                        Expanded(child: description),
                      ],
                    ),
                    const SizedBox(height: 12),
                    join,
                  ],
                )
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: description),
                    const SizedBox(width: 12),
                    join,
                  ],
                ),
        );
      },
    );
  }
}

/// Frosted glass modal dialog with large rounded corners (`32.0`) and Gaussian
/// backdrop blur.
