import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Single dock control.
///
/// With a label it renders as the reference row button: icon and label on one
/// line inside the white capsule group, 40 pt tall and 10 pt radius. Active
/// controls fill with the action color; danger controls fill with live red.
/// Without a label it keeps the compact square used on phones.
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
    this.activeForegroundColor,
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
  final Color? activeForegroundColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final accent = activeColor ?? style.accent;

    Color background;
    Color foreground;
    if (isDanger) {
      background = style.live;
      foreground = Colors.white;
    } else if (isActive) {
      background = accent;
      foreground =
          activeForegroundColor ??
          (accent == style.speak ||
                  accent == style.speakStrong ||
                  accent == style.live
              ? Colors.white
              : style.onAccent);
    } else {
      background = Colors.transparent;
      foreground = style.textSecondary;
    }

    final badge = Badge(
      isLabelVisible: (badgeCount != null && badgeCount! > 0) || showBadgeDot,
      backgroundColor: style.live,
      label: badgeCount != null && badgeCount! > 0
          ? Text(
              badgeCount! > 9 ? '9+' : '$badgeCount',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            )
          : null,
      child: showLabel
          ? _inlineContent(style, background, foreground)
          : _stackedIcon(background, foreground, style),
    );

    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      selected: isActive,
      label: label,
      child: Tooltip(
        message: tooltip ?? label,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            showLabel
                ? RealtimeUiTokens.compactRadius
                : RealtimeUiTokens.controlRadius,
          ),
          onTap: isLoading || onPressed == null
              ? null
              : () {
                  unawaited(HapticFeedback.lightImpact());
                  onPressed?.call();
                },
          child: Padding(
            padding: showLabel
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: badge,
          ),
        ),
      ),
    );
  }

  /// Reference dock row: icon + label in one 40 pt capsule.
  ///
  /// Falls back to the compact square when an ancestor gives the item less
  /// room than the icon and label need (for example a fixed-width toolbar).
  Widget _inlineContent(
    RealtimeStyle style,
    Color background,
    Color foreground,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth && constraints.maxWidth < 64) {
          return _stackedIcon(background, foreground, style);
        }
        return AnimatedContainer(
          duration: RealtimeUiTokens.animFast,
          curve: Curves.easeOutCubic,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isActive || isDanger
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stackedIcon(Color background, Color foreground, RealtimeStyle style) {
    return AnimatedContainer(
      duration: RealtimeUiTokens.animFast,
      curve: Curves.easeOutCubic,
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        border: isDanger || isActive
            ? null
            : Border.all(color: style.border, width: 1),
      ),
      child: Center(
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foreground,
                ),
              )
            : Icon(icon, size: 20, color: foreground),
      ),
    );
  }
}
