part of '../flutter_realtime_design_ui.dart';

class RealtimeFloatingPill extends StatelessWidget {
  const RealtimeFloatingPill({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.textColor = Colors.white,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final opaque =
        !RealtimeUiThemeExtension.of(context).glassEnabled ||
        MediaQuery.highContrastOf(context);
    Widget pill = ClipRRect(
      borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
      child: BackdropFilter(
        enabled: !opaque,
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: opaque
                ? (backgroundColor ?? Colors.black).withValues(alpha: 1)
                : backgroundColor ?? Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 0.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: iconColor ?? textColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      pill = GestureDetector(onTap: onTap, child: pill);
    }
    return pill;
  }
}
