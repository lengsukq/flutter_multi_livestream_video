import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'realtime_dock_more_item.dart';

class MeetingDockMoreActionGridItem extends StatelessWidget {
  const MeetingDockMoreActionGridItem({
    required this.item,
    required this.onTap,
  });

  final RealtimeDockMoreItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final appearance = RealtimeUiThemeExtension.of(context);
    final foreground = item.isDanger
        ? style.live
        : item.isActive
        ? style.onAccent
        : item.accentColor ?? style.text;
    final background = item.isDanger
        ? style.dangerSubtle
        : item.isActive
        ? style.accent
        : style.surfaceSubtle;

    return Semantics(
      button: true,
      enabled: item.enabled,
      selected: item.isActive,
      child: Opacity(
        opacity: item.enabled ? 1 : .45,
        child: InkWell(
          onTap: item.enabled ? onTap : null,
          borderRadius: BorderRadius.circular(appearance.controlRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible:
                      item.showBadgeDot ||
                      (item.badgeText != null && item.badgeText!.isNotEmpty),
                  label: item.badgeText != null ? Text(item.badgeText!) : null,
                  smallSize: 8,
                  backgroundColor: style.live,
                  child: AnimatedContainer(
                    duration: appearance.duration(
                      context,
                      RealtimeUiTokens.animNormal,
                    ),
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(
                        appearance.controlRadius,
                      ),
                      border: Border.all(
                        color: item.isDanger
                            ? style.live.withValues(alpha: .3)
                            : item.isActive
                            ? style.accent
                            : style.border,
                      ),
                    ),
                    child: Icon(item.icon, color: foreground, size: 24),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.isDanger ? style.live : style.text,
                  ),
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: style.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
