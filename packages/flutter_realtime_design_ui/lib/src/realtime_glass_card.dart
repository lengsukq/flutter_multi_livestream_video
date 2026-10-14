part of '../flutter_realtime_design_ui.dart';

class RealtimeGlassCard extends StatelessWidget {
  const RealtimeGlassCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.radius = RealtimeUiTokens.cardRadius,
    this.opacity = 0.88,
    this.blur = RealtimeUiTokens.subtleBlur,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double opacity;
  final double blur;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final hasHeader = title != null || icon != null;

    return RealtimeCardSurface(
      margin: margin,
      padding: padding,
      radius: radius,
      borderColor: borderColor ?? RealtimeUiTokens.border,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (iconColor ?? style.primary).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: 19,
                      color: iconColor ?? style.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: style.text,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: style.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
