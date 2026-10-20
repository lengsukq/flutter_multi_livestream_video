import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Thin bar above the media stage: layout tabs on the left, view actions on
/// the right. Shared content replaces the layout tabs with page tabs.
class RealtimeMeetingStageBar extends StatelessWidget {
  const RealtimeMeetingStageBar({
    super.key,
    this.tabs = const [],
    this.selectedTab = 0,
    this.onTabSelected,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 0),
  });

  final List<String> tabs;
  final int selectedTab;
  final ValueChanged<int>? onTabSelected;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < RealtimeBreakpoints.compactMaxWidth;
          final tabRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 6),
                  child: _StageTab(
                    label: tabs[i],
                    selected: i == selectedTab,
                    onTap: onTabSelected == null
                        ? null
                        : () => onTabSelected!(i),
                  ),
                ),
            ],
          );
          if (compact) {
            return Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: tabRow,
                  ),
                ),
                ...actions,
              ],
            );
          }
          return Row(
            children: [
              tabRow,
              const Spacer(),
              for (final action in actions)
                Padding(padding: const EdgeInsets.only(left: 4), child: action),
            ],
          );
        },
      ),
    );
  }
}

class _StageTab extends StatelessWidget {
  const _StageTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: RealtimeUiTokens.animFast,
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? style.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? style.border : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? style.text : style.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
