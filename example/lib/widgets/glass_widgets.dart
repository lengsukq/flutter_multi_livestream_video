import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

/// Thin adapter forwarding to the SDK's built-in [RealtimeGlassSurface].
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = RealtimeUiTokens.cardRadius,
    this.blur = RealtimeUiTokens.blur,
    this.opacity = 0.84,
    this.padding,
    this.margin,
    this.borderColor,
    this.fillColor,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Color? fillColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => RealtimeGlassSurface(
    radius: borderRadius,
    blur: blur,
    opacity: opacity,
    padding: padding,
    margin: margin,
    borderColor: borderColor ?? RealtimeUiTokens.border,
    fillColor: fillColor,
    onTap: onTap,
    child: child,
  );
}

/// Thin adapter forwarding to the SDK's built-in [RealtimeAmbientBackground].
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RealtimeAmbientBackground(child: child);
}

/// Thin adapter forwarding to the SDK's built-in [RealtimeGlassTextField].
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => RealtimeGlassTextField(
    controller: controller,
    label: label,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffix: suffix,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    onChanged: onChanged,
  );
}

/// Thin adapter forwarding to the SDK's built-in [RealtimeGlassButton].
class GlassGradientButton extends StatelessWidget {
  const GlassGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => RealtimeGlassButton(
    onPressed: onPressed,
    icon: icon,
    isLoading: isLoading,
    child: child,
  );
}
