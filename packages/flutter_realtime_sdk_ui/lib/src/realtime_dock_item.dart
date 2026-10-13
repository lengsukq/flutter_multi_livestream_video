import 'package:flutter/material.dart';

class RealtimeDockItem extends StatelessWidget {
  const RealtimeDockItem({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.isActive = false,
    this.isDanger = false,
    this.badgeCount,
    this.showBadgeDot = false,
    this.showLabel = true,
    this.isLoading = false,
    this.activeColor,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;
  final bool isDanger;
  final int? badgeCount;
  final bool showBadgeDot;
  final bool showLabel;
  final bool isLoading;
  final Color? activeColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = activeColor ?? theme.colorScheme.primary;

    Color iconBgColor;
    Color iconColor;

    if (isDanger) {
      iconBgColor = const Color(
        0xFFFF3B30,
      ).withValues(alpha: isDark ? 0.35 : 0.14);
      iconColor = const Color(0xFFFF3B30);
    } else if (isActive) {
      iconBgColor = primaryColor.withValues(alpha: isDark ? 0.35 : 0.18);
      iconColor = primaryColor;
    } else {
      iconBgColor = (isDark ? Colors.white : Colors.black).withValues(
        alpha: 0.06,
      );
      iconColor = theme.colorScheme.onSurface;
    }

    final buttonContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Badge(
          isLabelVisible:
              (badgeCount != null && badgeCount! > 0) || showBadgeDot,
          label: badgeCount != null && badgeCount! > 0
              ? Text('$badgeCount', style: const TextStyle(fontSize: 9))
              : null,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(13),
              border: isActive && !isDanger
                  ? Border.all(
                      color: primaryColor.withValues(alpha: 0.4),
                      width: 1,
                    )
                  : null,
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Tooltip(
      message: tooltip ?? label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: buttonContent,
        ),
      ),
    );
  }
}

/// A unified Glassmorphic Meeting Dock for conference and classroom rooms.
///
/// Groups controls cleanly into Media, Sharing, Panels, and Exit zones,
/// preventing multi-row clutter and broken layouts.
