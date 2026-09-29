import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_provider_label.dart';
import 'realtime_strings.dart';

/// Shared visual language for the built-in Realtime SDK surfaces.
///
/// Keep provider-specific UI out of this layer. Meeting, Live, Attached Chat,
/// Standalone Chat, and Demo lobbies all consume the same tokens and surfaces.
abstract final class RealtimeUiTokens {
  static const background = Color(0xFFF4F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const borderGlass = Color(0xF0FFFFFF);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);

  static const primary = Color(0xFF4F46E5);
  static const primaryAccent = Color(0xFF6366F1);
  static const primarySubtle = Color(0xFFEEF2FF);
  static const primaryBorder = Color(0xFFC7D2FE);
  static const success = Color(0xFF059669);
  static const successSubtle = Color(0xFFECFDF5);
  static const successBorder = Color(0xFFA7F3D0);
  static const warning = Color(0xFFD97706);
  static const warningSubtle = Color(0xFFFFFBEB);
  static const danger = Color(0xFFDC2626);
  static const dangerSubtle = Color(0xFFFEF2F2);
  static const dangerBorder = Color(0xFFFECDD3);

  /// Unified large border radius hierarchy across the entire SDK.
  static const sheetRadius = 32.0;
  static const dockRadius = 30.0;
  static const cardRadius = 28.0;
  static const controlRadius = 22.0;
  static const compactRadius = 16.0;
  static const pillRadius = 999.0;

  static const blur = 24.0;
  static const subtleBlur = 16.0;

  static const pagePadding = 16.0;
  static const sectionGap = 16.0;

  static const animFast = Duration(milliseconds: 160);
  static const animNormal = Duration(milliseconds: 240);
  static const animSlow = Duration(milliseconds: 340);

  static const primaryGradient = LinearGradient(
    colors: [primary, primaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassGradient({double opacity = 0.84}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface.withValues(alpha: (opacity + 0.08).clamp(0.0, 0.98)),
          surface.withValues(alpha: (opacity - 0.06).clamp(0.0, 0.96)),
        ],
      );

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: .06),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF4F46E5).withValues(alpha: .03),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get primaryGlowShadow => [
    BoxShadow(
      color: primary.withValues(alpha: .26),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Ready-to-use Material 3 theme aligned with the SDK's large-radius frosted
/// glass visual language.
abstract final class RealtimeUiTheme {
  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    // Web runtimes can fail to resolve some CJK glyphs through the default
    // platform fallback. Name common system CJK families explicitly; missing
    // families are skipped and Flutter still uses the platform fallback after
    // this list.
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'PingFang SC',
      'Microsoft YaHei',
      'Hiragino Sans GB',
    ],
    scaffoldBackgroundColor: RealtimeUiTokens.background,
    colorScheme: const ColorScheme.light(
      primary: RealtimeUiTokens.primary,
      onPrimary: Colors.white,
      secondary: RealtimeUiTokens.primaryAccent,
      surface: RealtimeUiTokens.surface,
      onSurface: RealtimeUiTokens.text,
      surfaceContainerHighest: RealtimeUiTokens.surfaceSubtle,
      outline: RealtimeUiTokens.border,
      error: RealtimeUiTokens.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: RealtimeUiTokens.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: RealtimeUiTokens.text,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.90),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.sheetRadius),
        side: const BorderSide(color: RealtimeUiTokens.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.90),
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: Colors.white.withValues(alpha: 0.90),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RealtimeUiTokens.sheetRadius),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        side: const BorderSide(color: RealtimeUiTokens.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RealtimeUiTokens.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RealtimeUiTokens.text,
        backgroundColor: Colors.white.withValues(alpha: 0.68),
        side: const BorderSide(color: RealtimeUiTokens.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: RealtimeUiTokens.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        side: const BorderSide(color: RealtimeUiTokens.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: RealtimeUiTokens.text.withValues(alpha: 0.92),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.76),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        borderSide: const BorderSide(color: RealtimeUiTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        borderSide: const BorderSide(color: RealtimeUiTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        borderSide: const BorderSide(
          color: RealtimeUiTokens.primary,
          width: 1.5,
        ),
      ),
    ),
  );
}

/// Multi-orb ambient mesh background that gives frosted glass surfaces rich
/// depth and subtle color refraction.
class RealtimeAmbientBackground extends StatelessWidget {
  const RealtimeAmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RealtimeUiTokens.background,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          left: -110,
          top: -130,
          child: _AmbientOrb(size: 380, color: Color(0xFFD9E2FF)),
        ),
        const Positioned(
          right: -120,
          top: 80,
          child: _AmbientOrb(size: 320, color: Color(0xFFEDE9FE)),
        ),
        const Positioned(
          left: -60,
          bottom: 120,
          child: _AmbientOrb(size: 290, color: Color(0xFFE0F2FE)),
        ),
        const Positioned(
          right: -110,
          bottom: -140,
          child: _AmbientOrb(size: 400, color: Color(0xFFDBEAFE)),
        ),
        child,
      ],
    ),
  );
}

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

/// Core frosted glass surface with Gaussian blur, translucent gradient fill,
/// specular border highlight, and soft elevation shadow.
class RealtimeGlassSurface extends StatelessWidget {
  const RealtimeGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = RealtimeUiTokens.cardRadius,
    this.opacity = .82,
    this.blur = RealtimeUiTokens.blur,
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
    Widget content = AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      padding: padding ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: fillColor?.withValues(alpha: opacity),
        gradient: fillColor == null
            ? RealtimeUiTokens.glassGradient(opacity: opacity)
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor == RealtimeUiTokens.border
              ? RealtimeUiTokens.border.withValues(alpha: .88)
              : borderColor,
          width: 1.1,
        ),
        boxShadow: shadow ? RealtimeUiTokens.cardShadow : const [],
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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        ),
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
    final pill = AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.pillRadius),
        border: Border.all(color: borderColor),
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
            Icon(icon, size: 13.5, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
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

/// Frosted glass icon button used across room HUD bars and panels.
class RealtimeGlassIconButton extends StatelessWidget {
  const RealtimeGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.active = false,
    this.danger = false,
    this.badgeCount = 0,
    this.size = 44,
    this.radius = RealtimeUiTokens.controlRadius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool active;
  final bool danger;
  final int badgeCount;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bgColor = danger
        ? RealtimeUiTokens.danger
        : active
        ? RealtimeUiTokens.primarySubtle
        : Colors.white.withValues(alpha: 0.78);
    final borderColor = danger
        ? RealtimeUiTokens.danger
        : active
        ? RealtimeUiTokens.primaryBorder
        : RealtimeUiTokens.border;
    final fgColor = danger
        ? Colors.white
        : active
        ? RealtimeUiTokens.primary
        : RealtimeUiTokens.textMuted;

    Widget button = RealtimeGlassPressable(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(radius),
          child: AnimatedContainer(
            duration: RealtimeUiTokens.animNormal,
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 1.1),
              boxShadow: danger
                  ? [
                      BoxShadow(
                        color: RealtimeUiTokens.danger.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : active
                  ? [
                      BoxShadow(
                        color: RealtimeUiTokens.primary.withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 19, color: fgColor),
                if (badgeCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: RealtimeUiTokens.animNormal,
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: BoxDecoration(
                          color: RealtimeUiTokens.danger,
                          borderRadius: BorderRadius.circular(
                            RealtimeUiTokens.pillRadius,
                          ),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Focus-aware frosted glass text field with large rounded corners and
/// optional action suffix slot.
class RealtimeGlassTextField extends StatefulWidget {
  const RealtimeGlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<RealtimeGlassTextField> createState() => _RealtimeGlassTextFieldState();
}

class _RealtimeGlassTextFieldState extends State<RealtimeGlassTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: RealtimeUiTokens.animNormal,
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      color: _focused
          ? Colors.white.withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      border: Border.all(
        color: _focused ? RealtimeUiTokens.primary : RealtimeUiTokens.border,
        width: _focused ? 1.5 : 1.1,
      ),
      boxShadow: _focused
          ? [
              BoxShadow(
                color: RealtimeUiTokens.primary.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
          : const [],
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            style: const TextStyle(
              color: RealtimeUiTokens.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: TextStyle(
                color: _focused
                    ? RealtimeUiTokens.primary
                    : RealtimeUiTokens.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              hintText: widget.hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _focused
                          ? RealtimeUiTokens.primary
                          : const Color(0xFF6366F1),
                      size: 19,
                    )
                  : null,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        if (widget.suffix != null) ...[
          const SizedBox(width: 6),
          widget.suffix!,
        ],
      ],
    ),
  );
}

/// Primary gradient / secondary frosted glass button with tactile press scale
/// and loading state.
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
    final enabled = onPressed != null && !isLoading;
    final foregroundColor = secondary
        ? (enabled ? RealtimeUiTokens.text : const Color(0xFF94A3B8))
        : (enabled ? Colors.white : const Color(0xFF94A3B8));

    return RealtimeGlassPressable(
      borderRadius: RealtimeUiTokens.controlRadius,
      child: AnimatedContainer(
        duration: RealtimeUiTokens.animNormal,
        curve: Curves.easeOutCubic,
        height: 50,
        decoration: BoxDecoration(
          color: secondary
              ? Colors.white.withValues(alpha: enabled ? 0.80 : 0.50)
              : null,
          gradient: secondary
              ? null
              : (enabled
                    ? RealtimeUiTokens.primaryGradient
                    : const LinearGradient(
                        colors: [Color(0xFFE2E8F0), Color(0xFFE2E8F0)],
                      )),
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
          border: Border.all(
            color: secondary
                ? RealtimeUiTokens.borderStrong
                : (enabled
                      ? Colors.white.withValues(alpha: 0.24)
                      : Colors.transparent),
          ),
          boxShadow: enabled && !secondary
              ? RealtimeUiTokens.primaryGlowShadow
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
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
                        DefaultTextStyle(
                          style: TextStyle(
                            color: foregroundColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          child: child,
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

/// Interactive frosted glass cards for selecting between Meeting and Live
/// room modes.
class RealtimeModeSelector extends StatelessWidget {
  const RealtimeModeSelector({
    super.key,
    required this.selectedMode,
    required this.onChanged,
  });

  final MediaRoomMode selectedMode;
  final ValueChanged<MediaRoomMode>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: _ModeOptionCard(
              mode: MediaRoomMode.meeting,
              title: RealtimeStrings.of(context).meeting,
              subtitle: RealtimeStrings.of(context).meetingModeSubtitle,
              icon: Icons.groups_2_rounded,
              selected: selectedMode == MediaRoomMode.meeting,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(MediaRoomMode.meeting),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ModeOptionCard(
              mode: MediaRoomMode.broadcast,
              title: RealtimeStrings.of(context).live,
              subtitle: RealtimeStrings.of(context).liveModeSubtitle,
              icon: Icons.podcasts_rounded,
              selected: selectedMode == MediaRoomMode.broadcast,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(MediaRoomMode.broadcast),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: RealtimeUiTokens.animFast,
        child: Text(
          selectedMode == MediaRoomMode.meeting
              ? RealtimeStrings.of(context).meetingModeDescription
              : RealtimeStrings.of(context).liveModeDescription,
          key: ValueKey(selectedMode),
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: RealtimeUiTokens.textMuted,
          ),
        ),
      ),
    ],
  );
}

class _ModeOptionCard extends StatelessWidget {
  const _ModeOptionCard({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final MediaRoomMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RealtimeGlassPressable(
    onTap: onTap,
    borderRadius: RealtimeUiTokens.controlRadius,
    child: AnimatedContainer(
      duration: RealtimeUiTokens.animNormal,
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? RealtimeUiTokens.primarySubtle.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        border: Border.all(
          color: selected ? RealtimeUiTokens.primary : RealtimeUiTokens.border,
          width: selected ? 1.5 : 1.0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: RealtimeUiTokens.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: RealtimeUiTokens.animNormal,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected
                  ? RealtimeUiTokens.primary
                  : RealtimeUiTokens.surfaceSubtle,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : RealtimeUiTokens.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? RealtimeUiTokens.primary
                        : RealtimeUiTokens.text,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: RealtimeUiTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Reusable frosted glass card for displaying an active room in a discovery
/// list.
class RealtimeRoomCard extends StatelessWidget {
  const RealtimeRoomCard({super.key, required this.room, required this.onJoin});

  final MediaRoomSummary room;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final isBroadcast = room.roomMode == MediaRoomMode.broadcast;
    final strings = RealtimeStrings.of(context);
    final modeLabel = isBroadcast ? strings.live : strings.meeting;
    final providerLabel = mediaProviderDisplayName(room.providerId);

    return RealtimeGlassSurface(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: RealtimeUiTokens.controlRadius,
      opacity: 0.84,
      blur: RealtimeUiTokens.subtleBlur,
      onTap: onJoin,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isBroadcast
                  ? const Color(0xFFFFF1F2)
                  : RealtimeUiTokens.primarySubtle,
              borderRadius: BorderRadius.circular(
                RealtimeUiTokens.compactRadius,
              ),
              border: Border.all(
                color: isBroadcast
                    ? const Color(0xFFFECDD3)
                    : RealtimeUiTokens.primaryBorder,
              ),
            ),
            child: Icon(
              isBroadcast ? Icons.podcasts_rounded : Icons.groups_2_rounded,
              size: 20,
              color: isBroadcast
                  ? const Color(0xFFE11D48)
                  : RealtimeUiTokens.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.roomCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: RealtimeUiTokens.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  strings.roomSummary(
                    modeLabel,
                    providerLabel,
                    room.attendeeCount,
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: RealtimeUiTokens.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: onJoin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  RealtimeUiTokens.pillRadius,
                ),
              ),
            ),
            child: Text(
              strings.join,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted glass modal dialog with large rounded corners (`32.0`) and Gaussian
/// backdrop blur.
class RealtimeGlassDialog extends StatelessWidget {
  const RealtimeGlassDialog({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.iconColor = RealtimeUiTokens.primary,
    this.iconBackground = RealtimeUiTokens.primarySubtle,
    this.actions = const [],
    this.maxWidth = 480,
  });

  final Widget title;
  final Widget content;
  final IconData? icon;
  final Color iconColor;
  final Color iconBackground;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: RealtimeGlassSurface(
        radius: RealtimeUiTokens.sheetRadius,
        opacity: 0.92,
        blur: RealtimeUiTokens.blur,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(
                        RealtimeUiTokens.compactRadius,
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: RealtimeUiTokens.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                    child: title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(child: content),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Presents a frosted glass modal bottom sheet with `32.0` top corners and a
/// glass pill drag handle.
Future<T?> showRealtimeGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0xFF0F172A).withValues(alpha: 0.32),
  elevation: 0,
  builder: (sheetContext) => ClipRRect(
    borderRadius: const BorderRadius.vertical(
      top: Radius.circular(RealtimeUiTokens.sheetRadius),
    ),
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: RealtimeUiTokens.blur,
        sigmaY: RealtimeUiTokens.blur,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RealtimeUiTokens.glassGradient(opacity: 0.92),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(RealtimeUiTokens.sheetRadius),
          ),
          border: const Border(
            top: BorderSide(color: RealtimeUiTokens.borderGlass, width: 1.4),
          ),
          boxShadow: RealtimeUiTokens.cardShadow,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: RealtimeUiTokens.borderStrong,
                    borderRadius: BorderRadius.circular(
                      RealtimeUiTokens.pillRadius,
                    ),
                  ),
                ),
              ),
              Flexible(child: builder(sheetContext)),
            ],
          ),
        ),
      ),
    ),
  ),
);

class RealtimeSheetHeader extends StatelessWidget {
  const RealtimeSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.admin_panel_settings_outlined,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: RealtimeUiTokens.primarySubtle,
          borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
          border: Border.all(color: RealtimeUiTokens.primaryBorder),
        ),
        child: Icon(icon, color: RealtimeUiTokens.primary, size: 21),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: RealtimeUiTokens.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: RealtimeUiTokens.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

class RealtimeDangerButton extends StatelessWidget {
  const RealtimeDangerButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => RealtimeGlassPressable(
    borderRadius: RealtimeUiTokens.controlRadius,
    child: FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: RealtimeUiTokens.danger,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        ),
      ),
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: .68), color.withValues(alpha: 0)],
      ),
    ),
  );
}
