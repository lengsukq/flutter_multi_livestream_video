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

  Color _resolveAccent(BuildContext context, bool isDark) {
    if (item.accentColor != null) return item.accentColor!;
    if (item.isDanger) return RealtimeUiTokens.iosRed;
    if (item.isActive) return RealtimeUiTokens.iosOrange;

    final code = item.icon.codePoint;
    if (code == Icons.cameraswitch_rounded.codePoint ||
        code == Icons.switch_camera_rounded.codePoint) {
      return RealtimeUiTokens.iosTeal;
    }
    if (code == Icons.blur_on_rounded.codePoint ||
        code == Icons.auto_awesome_rounded.codePoint ||
        code == Icons.palette_outlined.codePoint) {
      return RealtimeUiTokens.iosIndigo;
    }
    if (code == Icons.fiber_manual_record_rounded.codePoint ||
        code == Icons.radio_button_checked_rounded.codePoint ||
        code == Icons.stop_circle_outlined.codePoint ||
        code == Icons.stop_circle_rounded.codePoint) {
      return RealtimeUiTokens.iosRed;
    }
    if (code == Icons.build_outlined.codePoint ||
        code == Icons.handyman_outlined.codePoint ||
        code == Icons.construction_rounded.codePoint) {
      return RealtimeUiTokens.iosOrange;
    }
    if (code == Icons.cloud_download_outlined.codePoint ||
        code == Icons.cloud_download_rounded.codePoint ||
        code == Icons.download_rounded.codePoint) {
      return RealtimeUiTokens.iosBlue;
    }
    return isDark ? RealtimeUiTokens.iosBlue : RealtimeUiTokens.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _resolveAccent(context, isDark);

    return InkWell(
      onTap: item.enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
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
              backgroundColor: RealtimeUiTokens.iosRed,
              child: AnimatedContainer(
                duration: RealtimeUiTokens.animNormal,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.isDanger
                      ? RealtimeUiTokens.iosRed.withValues(alpha: 0.16)
                      : (item.isActive
                            ? accent.withValues(alpha: 0.20)
                            : accent.withValues(alpha: isDark ? 0.14 : 0.09)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.isDanger
                        ? RealtimeUiTokens.iosRed.withValues(alpha: 0.6)
                        : (item.isActive
                              ? accent.withValues(alpha: 0.7)
                              : accent.withValues(alpha: isDark ? 0.25 : 0.20)),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (item.isDanger ? RealtimeUiTokens.iosRed : accent)
                          .withValues(alpha: isDark ? 0.25 : 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    item.icon,
                    color: item.isDanger
                        ? RealtimeUiTokens.iosRed
                        : (item.isActive
                              ? accent
                              : (isDark ? Colors.white : accent)),
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: item.isActive || item.isDanger
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: item.isDanger
                    ? RealtimeUiTokens.iosRed
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
            if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : RealtimeUiTokens.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dock "More" button consolidating secondary media controls and tools
/// (flip camera, background effects, recording, teacher tools, etc.).
