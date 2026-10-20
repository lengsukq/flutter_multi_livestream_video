import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'realtime_dock_item.dart';
import 'realtime_dock_more_item.dart';
import 'meeting_dock_more_action_grid_item.dart';
import 'meeting_dock_meeting_dock_modal_sheet.dart';

class RealtimeDockMoreButton extends StatelessWidget {
  const RealtimeDockMoreButton({
    super.key,
    this.items = const [],
    this.children = const [],
    this.showLabel = true,
    this.hasActiveBadge = false,
  });

  final List<RealtimeDockMoreItem> items;
  final List<Widget> children;
  final bool showLabel;
  final bool hasActiveBadge;

  @override
  Widget build(BuildContext context) {
    final strings = RealtimeStrings.of(context);

    void openMenu() {
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (sheetContext) => MeetingDockMeetingDockModalSheet(
            title: strings.more,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final crossAxisCount = (availableWidth / (88 * scale))
                      .floor()
                      .clamp(2, 6);
                  final itemWidth =
                      (availableWidth - (crossAxisCount - 1) * 10) /
                      crossAxisCount;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (items.isNotEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.start,
                          children: [
                            for (final item in items)
                              SizedBox(
                                width: itemWidth,
                                child: MeetingDockMoreActionGridItem(
                                  item: item,
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    item.onTap();
                                  },
                                ),
                              ),
                          ],
                        ),
                      if (children.isNotEmpty) ...[
                        if (items.isNotEmpty) const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: RealtimeStyle.of(context).surfaceSubtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: RealtimeStyle.of(context).border,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: children,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    return RealtimeDockItem(
      icon: Icons.more_horiz_rounded,
      label: strings.more,
      showBadgeDot: hasActiveBadge,
      showLabel: showLabel,
      onPressed: (items.isEmpty && children.isEmpty) ? null : openMenu,
    );
  }
}

/// Modern card item for the share content selection modal.
