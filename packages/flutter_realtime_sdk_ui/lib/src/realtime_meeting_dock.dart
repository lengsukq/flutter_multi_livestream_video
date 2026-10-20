import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Floating room controls.
///
/// Groups are rendered as separate white capsules (media, collaboration,
/// panels, exit) exactly like the reference dock. Narrow windows keep the two
/// primary media actions and the exit visible, and let the rest scroll.
class RealtimeMeetingDock extends StatelessWidget {
  const RealtimeMeetingDock({
    super.key,
    required this.mediaGroup,
    this.collaborationGroup = const [],
    this.panelsGroup = const [],
    this.exitAction,
    this.leadingStatus,
    this.moreAction,
    this.showLabels = true,
  });
  final List<Widget> mediaGroup;
  final List<Widget> collaborationGroup;
  final List<Widget> panelsGroup;
  final Widget? exitAction;
  final Widget? leadingStatus;
  final Widget? moreAction;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow =
              constraints.maxWidth < RealtimeBreakpoints.compactMaxWidth;
          // Phones pin mic/camera and the exit action. Panel toggles come
          // first in the scroll region so chat/members stay one tap away;
          // sharing extras and More follow.
          final narrowSecondary = [
            ...panelsGroup,
            ...mediaGroup.skip(2),
            ...collaborationGroup,
            if (moreAction != null) moreAction!,
          ];
          Widget group(List<Widget> children) => Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: style.surface,
              borderRadius: BorderRadius.circular(RealtimeUiTokens.dockRadius),
              border: Border.all(color: style.border),
              boxShadow: style.cardShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  children[i],
                ],
              ],
            ),
          );

          if (narrow) {
            return Row(
              children: [
                group(mediaGroup.take(2).toList(growable: false)),
                if (narrowSecondary.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: narrowSecondary,
                        ),
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (exitAction != null) ...[
                  const SizedBox(width: 6),
                  group([exitAction!]),
                ],
              ],
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (leadingStatus != null) ...[
                  leadingStatus!,
                  const SizedBox(width: 8),
                ],
                group(mediaGroup),
                if (collaborationGroup.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  group(collaborationGroup),
                ],
                if (panelsGroup.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  group(panelsGroup),
                ],
                if (moreAction != null) ...[
                  const SizedBox(width: 8),
                  group([moreAction!]),
                ],
                if (exitAction != null) ...[
                  const SizedBox(width: 8),
                  group([exitAction!]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
