import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Floating room navigation with a compact two-row arrangement for controls.
class RealtimeMeetingTopBar extends StatelessWidget {
  const RealtimeMeetingTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.badgeText = 'RT',
    this.centerActions = const [],
    this.trailingActions = const [],
    this.statusWidgets = const [],
    this.onHome,
    this.userAvatarUrl,
    this.userDisplayName,
    this.compact = false,
  });
  final String title;
  final String? subtitle;
  final String badgeText;
  final List<Widget> centerActions;
  final List<Widget> trailingActions;

  /// Connection, elapsed-time and recording indicators, below the room title.
  final List<Widget> statusWidgets;
  final VoidCallback? onHome;
  final String? userAvatarUrl;
  final String? userDisplayName;
  final bool compact;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    child: RealtimeGlassSurface(
      radius: RealtimeUiTokens.cardRadius,
      blur: RealtimeUiTokens.blur,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final small =
              compact ||
              constraints.maxWidth < 600 ||
              MediaQuery.textScalerOf(context).scale(17) >= 28;
          final style = RealtimeStyle.of(context);
          final identity = Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (statusWidgets.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: statusWidgets,
                  ),
                ],
                if (subtitle != null && !small)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          );
          final split = small && trailingActions.length > 2;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (onHome != null)
                    IconButton(
                      tooltip: RealtimeStrings.of(context).isZh ? '首页' : 'Home',
                      onPressed: onHome,
                      icon: const Icon(Icons.home_outlined),
                    ),
                  if (!small) ...[
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: style.surfaceSubtle,
                        borderRadius: BorderRadius.circular(
                          RealtimeUiTokens.compactRadius,
                        ),
                      ),
                      child: Text(
                        badgeText,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  identity,
                  if (!small) ...centerActions,
                  const SizedBox(width: 12),
                  if (split) trailingActions.last else ...trailingActions,
                  if (!small &&
                      (userDisplayName != null || userAvatarUrl != null)) ...[
                    const SizedBox(width: 8),
                    RealtimeAvatar(
                      name: userDisplayName ?? '',
                      avatarUrl: userAvatarUrl,
                      size: 36,
                    ),
                  ],
                ],
              ),
              if (split)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: trailingActions
                        .take(trailingActions.length - 1)
                        .toList(growable: false),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
