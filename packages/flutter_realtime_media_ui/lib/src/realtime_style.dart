import 'package:flutter/material.dart';

/// Unified reactive style and color palette management for Flutter Realtime SDK.
///
/// Automatically resolves complete semantic palettes based on current brightness
/// context, eliminating hardcoded contrast bugs across Light and Dark themes.
class RealtimeStyle {
  const RealtimeStyle({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceGlass,
    required this.border,
    required this.borderSubtle,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryAccent,
    required this.primarySubtle,
    required this.primaryBorder,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.danger,
    required this.dangerSubtle,
    required this.cardShadow,
    required this.glassGradient,
  });

  final bool isDark;
  bool get isLight => !isDark;
  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceGlass;
  final Color border;
  final Color borderSubtle;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primaryAccent;
  final Color primarySubtle;
  final Color primaryBorder;
  final Color success;
  final Color successSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color danger;
  final Color dangerSubtle;
  final List<BoxShadow> cardShadow;
  final LinearGradient glassGradient;

  /// Pure, clean white frosted glass light theme (Default).
  static const RealtimeStyle light = RealtimeStyle(
    isDark: false,
    background: Color(0xFFF4F7FB),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF1F5F9),
    surfaceGlass: Color(0xF2FFFFFF),
    border: Color(0xFFE2E8F0),
    borderSubtle: Color(0xFFF8FAFC),
    borderStrong: Color(0xFFCBD5E1),
    text: Color(0xFF0F172A), // Pure rich dark slate
    textSecondary: Color(0xFF334155), // Slate 700 - high contrast
    textMuted: Color(0xFF64748B), // Slate 500 - clear contrast
    primary: Color(0xFF4F46E5),
    primaryAccent: Color(0xFF6366F1),
    primarySubtle: Color(0xFFEEF2FF),
    primaryBorder: Color(0xFFC7D2FE),
    success: Color(0xFF059669),
    successSubtle: Color(0xFFECFDF5),
    warning: Color(0xFFD97706),
    warningSubtle: Color(0xFFFFFBEB),
    danger: Color(0xFFDC2626),
    dangerSubtle: Color(0xFFFEF2F2),
    cardShadow: [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 20, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x0A4F46E5), blurRadius: 10, offset: Offset(0, 2)),
    ],
    glassGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF5FFFFFF), Color(0xEBFFFFFF)],
    ),
  );

  /// Modern, deep dark slate theme with WCAG AAA high-contrast readability.
  static const RealtimeStyle dark = RealtimeStyle(
    isDark: true,
    background: Color(0xFF0B0F19), // Deep modern dark slate
    surface: Color(0xFF1E293B), // Slate 800 - distinct card surface
    surfaceSubtle: Color(0xFF151E2E), // Slate 900
    surfaceGlass: Color(0xE61E293B), // Translucent dark slate
    border: Color(0xFF334155), // Slate 700 - distinct border
    borderSubtle: Color(0x14FFFFFF), // 8% white subtle border
    borderStrong: Color(0xFF475569), // Slate 600
    text: Color(0xFFFFFFFF), // Pure crisp white!
    textSecondary: Color(0xFFE2E8F0), // Bright slate 200 - high contrast!
    textMuted: Color(0xFFCBD5E1), // Bright slate 300 - NEVER dark on dark!
    primary: Color(0xFF6366F1),
    primaryAccent: Color(0xFF818CF8),
    primarySubtle: Color(0xFF1E1B4B),
    primaryBorder: Color(0xFF4338CA),
    success: Color(0xFF10B981),
    successSubtle: Color(0xFF064E3B),
    warning: Color(0xFFF59E0B),
    warningSubtle: Color(0xFF78350F),
    danger: Color(0xFFEF4444),
    dangerSubtle: Color(0xFF7F1D1D),
    cardShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
    glassGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xF01E293B), Color(0xE60F172A)],
    ),
  );

  /// Access the active style dynamically resolving to Light or Dark mode.
  static RealtimeStyle of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
  }
}
