part of '../flutter_realtime_design_ui.dart';

class RealtimePill extends StatelessWidget {
  const RealtimePill({
    super.key,
    required this.label,
    this.icon,
    this.leadingDotColor,
    this.foreground = RealtimeUiTokens.textMuted,
    this.background = RealtimeUiTokens.surfaceSubtle,
    this.borderColor = RealtimeUiTokens.border,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? leadingDotColor;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final effectiveFg = foreground == RealtimeUiTokens.textMuted
        ? style.textMuted
        : (foreground == RealtimeUiTokens.text ? style.text : foreground);
    final effectiveBg = background == RealtimeUiTokens.surfaceSubtle
        ? style.surfaceSubtle
        : (background == RealtimeUiTokens.surface ? style.surface : background);
    final effectiveBorder = borderColor == RealtimeUiTokens.border
        ? style.border
        : (borderColor == RealtimeUiTokens.borderStrong
              ? style.borderStrong
              : borderColor);

    final pill = AnimatedContainer(
      duration: RealtimeUiThemeExtension.of(
        context,
      ).duration(context, RealtimeUiTokens.animNormal),
      curve: Curves.easeOutCubic,
      // Passive status chips stay compact; actionable chips provide the
      // minimum mobile touch target without relying on invisible overlays.
      constraints: onTap == null ? null : const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveBg.a < 0.99
            ? effectiveBg
            : effectiveBg.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        border: Border.all(color: effectiveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDotColor != null) ...[
            AnimatedContainer(
              duration: RealtimeUiThemeExtension.of(
                context,
              ).duration(context, RealtimeUiTokens.animNormal),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: leadingDotColor,
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 13.5, color: effectiveFg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: effectiveFg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;
    return RealtimeGlassPressable(
      onTap: onTap,
      borderRadius: RealtimeUiTokens.pillRadius,
      child: pill,
    );
  }
}
