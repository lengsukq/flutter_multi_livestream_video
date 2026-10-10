part of 'realtime_ui_style.dart';

/// Tactile press-scale wrapper for buttons, cards, and dock controls.
class RealtimeGlassPressable extends StatefulWidget {
  const RealtimeGlassPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.borderRadius = RealtimeUiTokens.controlRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double borderRadius;

  @override
  State<RealtimeGlassPressable> createState() => _RealtimeGlassPressableState();
}

class _RealtimeGlassPressableState extends State<RealtimeGlassPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    Widget scaled = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: RealtimeUiTokens.animFast,
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      scaled = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: scaled,
      );
    }

    return scaled;
  }
}

/// Core frosted glass surface with translucent gradient fill,
/// specular border highlight, soft elevation shadow, and optional Gaussian blur.
class RealtimeGlassSurface extends StatelessWidget {
  const RealtimeGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = RealtimeUiTokens.cardRadius,
    this.opacity = .82,
    this.blur = RealtimeUiTokens.subtleBlur,
    this.shadow = true,
    this.borderColor = RealtimeUiTokens.border,
    this.fillColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double opacity;
  final double blur;
  final bool shadow;
  final Color borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    Widget content = Container(
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: fillColor?.withValues(alpha: opacity),
        gradient: fillColor == null ? style.glassGradient : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor == RealtimeUiTokens.border
              ? style.border
              : borderColor,
          width: 1.1,
        ),
        boxShadow: shadow ? style.cardShadow : const [],
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: content,
        ),
      );
    }

    Widget surface = Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: blur > 0
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: content,
              )
            : content,
      ),
    );

    if (onTap != null) {
      surface = RealtimeGlassPressable(
        borderRadius: radius,
        pressedScale: 0.98,
        child: surface,
      );
    }

    return surface;
  }
}

/// Compact count or status badge pill.
class RealtimeBadge extends StatelessWidget {
  const RealtimeBadge({
    super.key,
    required this.text,
    this.color,
    this.backgroundColor,
    this.fontSize = 10.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  final String text;
  final Color? color;
  final Color? backgroundColor;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final fg = color ?? style.primary;
    final bg = backgroundColor ?? style.primarySubtle;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Standardized large-radius frosted glass card.
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

    return RealtimeGlassSurface(
      margin: margin,
      padding: padding,
      radius: radius,
      opacity: opacity,
      blur: blur,
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
                            fontSize: 12,
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

/// Data item for [RealtimeSegmentedTabs].
class RealtimeSegmentTab<T> {
  const RealtimeSegmentTab({
    required this.value,
    required this.label,
    this.icon,
    this.badge,
  });

  final T value;
  final String label;
  final IconData? icon;
  final int? badge;
}

/// Unified frosted glass segmented tab switcher.
class RealtimeSegmentedTabs<T> extends StatelessWidget {
  const RealtimeSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedValue,
    required this.onChanged,
    this.height = 46,
    this.radius = RealtimeUiTokens.controlRadius,
  });

  final List<RealtimeSegmentTab<T>> tabs;
  final T selectedValue;
  final ValueChanged<T> onChanged;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: style.surfaceSubtle,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: style.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = tabs.length;
          final tabWidth = (constraints.maxWidth) / count;
          final selectedIndex = tabs.indexWhere(
            (t) => t.value == selectedValue,
          );

          return Stack(
            children: [
              if (selectedIndex >= 0)
                AnimatedPositioned(
                  duration: RealtimeUiTokens.animNormal,
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: style.surface,
                      borderRadius: BorderRadius.circular(radius - 3),
                      border: Border.all(color: style.border),
                      boxShadow: style.cardShadow,
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: tabs.map((tab) {
                  final active = tab.value == selectedValue;
                  return Expanded(
                    child: RealtimeGlassPressable(
                      borderRadius: radius - 3,
                      onTap: () => onChanged(tab.value),
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tab.icon != null) ...[
                              Icon(
                                tab.icon,
                                size: 16,
                                color: active ? style.primary : style.textMuted,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                tab.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: active
                                      ? style.primary
                                      : style.textMuted,
                                ),
                              ),
                            ),
                            if (tab.badge != null && tab.badge! > 0) ...[
                              const SizedBox(width: 6),
                              RealtimeBadge(
                                text: '${tab.badge}',
                                color: active ? Colors.white : style.textMuted,
                                backgroundColor: active
                                    ? style.primary
                                    : style.borderStrong,
                                fontSize: 9.5,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Standard frosted glass list row / settings row.
class RealtimeGlassTile extends StatelessWidget {
  const RealtimeGlassTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.margin = const EdgeInsets.only(bottom: 8),
    this.radius = RealtimeUiTokens.controlRadius,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    return RealtimeGlassSurface(
      margin: margin,
      padding: padding,
      radius: radius,
      opacity: 0.88,
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: style.text,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: TextStyle(fontSize: 11.5, color: style.textMuted),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

/// Capsule status / metadata pill with smooth color transitions.
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
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveBg.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        border: Border.all(color: effectiveBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingDotColor != null) ...[
            AnimatedContainer(
              duration: RealtimeUiTokens.animNormal,
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: leadingDotColor,
                boxShadow: [
                  BoxShadow(
                    color: leadingDotColor!.withValues(alpha: 0.45),
                    blurRadius: 6,
                  ),
                ],
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
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
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
