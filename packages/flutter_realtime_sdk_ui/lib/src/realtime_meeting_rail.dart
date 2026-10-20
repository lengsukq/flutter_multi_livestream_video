import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Vertical teaching-tool rail used by the desktop meeting workspace.
///
/// Mirrors the reference classroom: 40 pt icon targets in a 56 pt column,
/// amber selection, quiet dividers between action groups. Tablets render the
/// same items as a horizontally scrolling bar.
class RealtimeMeetingRail extends StatelessWidget {
  const RealtimeMeetingRail({
    super.key,
    required this.items,
    this.horizontal = false,
  });

  final List<RealtimeMeetingRailItem> items;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final children = <Widget>[];
    for (final item in items) {
      if (item.isDivider) {
        children.add(
          horizontal
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: SizedBox(
                    width: 1,
                    height: 24,
                    child: ColoredBox(color: style.border),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: SizedBox(
                    width: 24,
                    height: 1,
                    child: ColoredBox(color: style.border),
                  ),
                ),
        );
        continue;
      }
      children.add(_RailButton(item: item, horizontal: horizontal));
    }

    if (horizontal) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: style.surface,
          border: Border(bottom: BorderSide(color: style.border)),
        ),
        child: SizedBox(
          height: 52,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: children),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 60,
      color: style.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }
}

class RealtimeMeetingRailItem {
  const RealtimeMeetingRailItem({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
    this.badgeCount = 0,
    this.danger = false,
  }) : isDivider = false;

  const RealtimeMeetingRailItem.divider()
    : icon = Icons.circle,
      tooltip = '',
      onPressed = null,
      active = false,
      badgeCount = 0,
      danger = false,
      isDivider = true;

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final int badgeCount;
  final bool danger;
  final bool isDivider;
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.item, required this.horizontal});
  final RealtimeMeetingRailItem item;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final iconColor = item.danger
        ? style.live
        : item.active
        ? style.onAccent
        : style.textSecondary;
    if (horizontal) {
      return Tooltip(
        message: item.tooltip,
        child: Semantics(
          button: true,
          selected: item.active,
          label: item.tooltip,
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
              onTap: item.onPressed,
              child: AnimatedContainer(
                duration: RealtimeUiTokens.animFast,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: item.active ? style.accentSoft : style.surfaceSubtle,
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                  border: Border.all(
                    color: item.active
                        ? style.primaryBorder
                        : style.borderSubtle,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(item.icon, size: 17, color: iconColor),
                    const SizedBox(width: 7),
                    Text(
                      item.tooltip,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: item.active
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final button = Tooltip(
      message: item.tooltip,
      child: Semantics(
        button: true,
        selected: item.active,
        label: item.tooltip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.onPressed,
            child: AnimatedContainer(
              duration: RealtimeUiTokens.animFast,
              curve: Curves.easeOutCubic,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.active
                    ? style.accent
                    : (item.danger ? style.dangerSubtle : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(item.icon, size: 20, color: iconColor),
                  if (item.badgeCount > 0)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: RealtimeBadge(text: '${item.badgeCount}'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return button;
  }
}
