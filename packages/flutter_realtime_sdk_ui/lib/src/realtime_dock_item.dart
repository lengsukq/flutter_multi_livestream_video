import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

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
    final primaryColor = activeColor ?? RealtimeUiTokens.appleTeal;

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
              ? Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.controlRadius,
              ),
              border: isActive && !isDanger
                  ? Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                      width: 1.2,
                    )
                  : Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(
                        alpha: 0.08,
                      ),
                      width: 0.6,
                    ),
            ),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, size: 21, color: iconColor),
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? primaryColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      selected: isActive,
      label: label,
      child: Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          onTap: isLoading || onPressed == null
              ? null
              : () {
                  unawaited(HapticFeedback.lightImpact());
                  onPressed?.call();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: buttonContent,
          ),
        ),
      ),
    );
  }
}

/// A unified Glassmorphic Meeting Dock for conference and classroom rooms.
///
/// Groups controls cleanly into Media, Sharing, Panels, and Exit zones,
/// preventing multi-row clutter and broken layouts.
