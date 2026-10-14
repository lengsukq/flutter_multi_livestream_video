import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Floating room controls. Primary media and exit actions remain visible;
/// secondary groups scroll independently when the window is narrow.
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
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: RealtimeGlassSurface(
      radius: RealtimeUiTokens.pillRadius,
      blur: RealtimeUiTokens.blur,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 600;
          final divider = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 1,
                color: RealtimeStyle.of(context).border,
              ),
            ),
          );
          final secondary = [
            ...mediaGroup.skip(2),
            ...collaborationGroup,
            ...panelsGroup,
            if (moreAction != null) moreAction!,
          ];
          if (narrow) {
            return Row(
              children: [
                ...mediaGroup.take(2),
                if (exitAction != null) exitAction!,
                if (secondary.isNotEmpty) ...[
                  divider,
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: secondary,
                      ),
                    ),
                  ),
                ],
              ],
            );
          }
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingStatus != null) ...[leadingStatus!, divider],
                ...mediaGroup,
                if (exitAction != null) ...[divider, exitAction!],
                if (collaborationGroup.isNotEmpty) ...[
                  divider,
                  ...collaborationGroup,
                ],
                if (panelsGroup.isNotEmpty) ...[divider, ...panelsGroup],
                if (moreAction != null) ...[divider, moreAction!],
              ],
            ),
          );
        },
      ),
    ),
  );
}
