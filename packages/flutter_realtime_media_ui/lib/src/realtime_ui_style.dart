import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared visual language for the built-in Realtime SDK surfaces.
///
/// Keep provider-specific UI out of this layer. Meeting, Live, Attached Chat
/// and Standalone Chat all consume the same tokens and surfaces.
abstract final class RealtimeUiTokens {
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);

  static const primary = Color(0xFF4F46E5);
  static const primarySubtle = Color(0xFFEEF2FF);
  static const success = Color(0xFF059669);
  static const successSubtle = Color(0xFFECFDF5);
  static const warning = Color(0xFFD97706);
  static const warningSubtle = Color(0xFFFFFBEB);
  static const danger = Color(0xFFDC2626);
  static const dangerSubtle = Color(0xFFFEF2F2);

  static const cardRadius = 22.0;
  static const controlRadius = 16.0;
  static const compactRadius = 12.0;
  static const blur = 18.0;

  static const pagePadding = 16.0;
  static const sectionGap = 16.0;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: .055),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withValues(alpha: .025),
      blurRadius: 5,
      offset: const Offset(0, 1),
    ),
  ];
}

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
          left: -120,
          top: -140,
          child: _AmbientOrb(size: 360, color: Color(0xFFE0E7FF)),
        ),
        const Positioned(
          right: -130,
          bottom: -150,
          child: _AmbientOrb(size: 390, color: Color(0xFFE0F2FE)),
        ),
        child,
      ],
    ),
  );
}

class RealtimeGlassSurface extends StatelessWidget {
  const RealtimeGlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = RealtimeUiTokens.cardRadius,
    this.opacity = .90,
    this.blur = RealtimeUiTokens.blur,
    this.shadow = true,
    this.borderColor = RealtimeUiTokens.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double opacity;
  final double blur;
  final bool shadow;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin ?? EdgeInsets.zero,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: RealtimeUiTokens.surface.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor.withValues(alpha: .92)),
            boxShadow: shadow ? RealtimeUiTokens.cardShadow : const [],
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    ),
  );
}

class RealtimePill extends StatelessWidget {
  const RealtimePill({
    super.key,
    required this.label,
    this.icon,
    this.foreground = RealtimeUiTokens.textMuted,
    this.background = RealtimeUiTokens.surfaceSubtle,
  });

  final String label;
  final IconData? icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: RealtimeUiTokens.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

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
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: RealtimeUiTokens.primarySubtle,
          borderRadius: BorderRadius.circular(14),
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
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: RealtimeUiTokens.danger,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      ),
    ),
    icon: Icon(icon),
    label: Text(label),
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
        colors: [color.withValues(alpha: .62), color.withValues(alpha: 0)],
      ),
    ),
  );
}
