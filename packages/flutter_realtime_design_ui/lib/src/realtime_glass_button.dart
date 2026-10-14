part of '../flutter_realtime_design_ui.dart';

class RealtimeGlassButton extends StatelessWidget {
  const RealtimeGlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.isLoading = false,
    this.secondary = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool isLoading;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final radius = RealtimeUiThemeExtension.of(context).controlRadius;
    final enabled = onPressed != null && !isLoading;
    final foregroundColor = secondary
        ? (enabled ? style.text : style.textMuted)
        : (enabled
              ? Colors.white
              : (style.isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8)));

    return RealtimeGlassPressable(
      borderRadius: radius,
      child: AnimatedContainer(
        duration: RealtimeUiThemeExtension.of(
          context,
        ).duration(context, RealtimeUiTokens.animNormal),
        curve: Curves.easeOutCubic,
        height: 50,
        decoration: BoxDecoration(
          color: secondary
              ? (enabled
                    ? style.surfaceSubtle
                    : style.surfaceSubtle.withValues(alpha: 0.50))
              : (enabled ? style.primary : style.border),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: secondary
                ? style.border
                : (enabled
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.transparent),
          ),
          boxShadow: enabled && !secondary
              ? (style.isDark
                    ? [
                        BoxShadow(
                          color: style.primary.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : style.cardShadow)
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: foregroundColor,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: foregroundColor, size: 18),
                          const SizedBox(width: 8),
                        ],
                        // The caption has to be allowed to shrink, otherwise a
                        // long label inside a constrained button overflows the
                        // surrounding Row instead of ellipsizing.
                        Flexible(
                          child: DefaultTextStyle(
                            style: Theme.of(context).textTheme.labelLarge!
                                .copyWith(
                                  color: foregroundColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                            child: child,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
