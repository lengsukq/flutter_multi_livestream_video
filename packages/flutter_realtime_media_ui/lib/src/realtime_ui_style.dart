import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_strings.dart';
import 'realtime_style.dart';

part 'realtime_ui_primitives.dart';
part 'realtime_ui_controls.dart';
part 'realtime_ui_cards_dialogs.dart';

/// Shared visual language for the built-in Realtime SDK surfaces.
///
/// Designed to align with Apple Human Interface Guidelines:
/// - Crisp, subtle outlines and squircle curvature
/// - iOS diffuse soft elevation shadows
/// - Frosted glass layer materials
abstract final class RealtimeUiTokens {
  static const background = Color(0xFFF2F2F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF8F8FA);
  static const border = Color(0xFFE5E7EB);
  static const borderStrong = Color(0xFFD1D5DB);
  static const borderGlass = Color(0xF0FFFFFF);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);

  // Apple System Colors
  static const iosBlue = Color(0xFF007AFF);
  static const iosGreen = Color(0xFF34C759);
  static const iosRed = Color(0xFFFF3B30);
  static const iosOrange = Color(0xFFFF9500);
  static const iosIndigo = Color(0xFF5856D6);
  static const iosTeal = Color(0xFF30B0C7);
  static const iosGray = Color(0xFF8E8E93);
  static const iosLightGray = Color(0xFFE5E5EA);

  static const primary = Color(0xFF007AFF);
  static const primaryAccent = Color(0xFF5856D6);
  static const primarySubtle = Color(0xFFEBF5FF);
  static const primaryBorder = Color(0xFFB9DBFE);
  static const success = Color(0xFF34C759);
  static const successSubtle = Color(0xFFEAF9EE);
  static const successBorder = Color(0xFFA6EBB5);
  static const warning = Color(0xFFFF9500);
  static const warningSubtle = Color(0xFFFFF7EB);
  static const danger = Color(0xFFFF3B30);
  static const dangerSubtle = Color(0xFFFEECEC);
  static const dangerBorder = Color(0xFFFECACA);

  /// Unified Apple HIG border radius hierarchy across the entire SDK.
  static const sheetRadius = 28.0;
  static const dockRadius = 26.0;
  static const cardRadius = 16.0;
  static const controlRadius = 12.0;
  static const compactRadius = 10.0;
  static const pillRadius = 999.0;

  static const blur = 20.0;
  static const subtleBlur = 12.0;

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

  static LinearGradient glassGradient({
    double opacity = 0.84,
    bool isDark = false,
  }) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isDark
        ? [
            const Color(
              0xFF1E293B,
            ).withValues(alpha: (opacity + 0.06).clamp(0.0, 0.98)),
            const Color(
              0xFF0F172A,
            ).withValues(alpha: (opacity - 0.06).clamp(0.0, 0.96)),
          ]
        : [
            surface.withValues(alpha: (opacity + 0.08).clamp(0.0, 0.98)),
            surface.withValues(alpha: (opacity - 0.06).clamp(0.0, 0.96)),
          ],
  );

  static List<BoxShadow> get cardShadow => iosCardShadow;

  /// iOS-style multi-layer diffuse soft shadows
  static List<BoxShadow> get iosSoftShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 28,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get iosCardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 8,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get iosDockShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardShadowTheme(bool isDark) => isDark
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ]
      : cardShadow;

  static List<BoxShadow> get primaryGlowShadow => [
    BoxShadow(
      color: primary.withValues(alpha: .24),
      blurRadius: 20,
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

  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamilyFallback: const [
      'Noto Sans CJK SC',
      'PingFang SC',
      'Microsoft YaHei',
      'Hiragino Sans GB',
    ],
    scaffoldBackgroundColor: RealtimeStyle.dark.background,
    colorScheme: ColorScheme.dark(
      primary: RealtimeStyle.dark.primary,
      onPrimary: Colors.white,
      secondary: RealtimeStyle.dark.primaryAccent,
      surface: RealtimeStyle.dark.surface,
      onSurface: RealtimeStyle.dark.text,
      surfaceContainerHighest: RealtimeStyle.dark.surfaceSubtle,
      outline: RealtimeStyle.dark.border,
      error: RealtimeStyle.dark.danger,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: RealtimeStyle.dark.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: RealtimeStyle.dark.text,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: RealtimeStyle.dark.surface.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.sheetRadius),
        side: BorderSide(color: RealtimeStyle.dark.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: RealtimeStyle.dark.surface.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: RealtimeStyle.dark.surface.withValues(alpha: 0.95),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RealtimeUiTokens.sheetRadius),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: RealtimeStyle.dark.surface.withValues(alpha: 0.90),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.cardRadius),
        side: BorderSide(color: RealtimeStyle.dark.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RealtimeStyle.dark.primary,
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
        foregroundColor: RealtimeStyle.dark.text,
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        side: BorderSide(color: RealtimeStyle.dark.border),
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
        foregroundColor: RealtimeStyle.dark.primaryAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RealtimeUiTokens.compactRadius),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: RealtimeStyle.dark.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        side: BorderSide(color: RealtimeStyle.dark.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: RealtimeStyle.dark.surface,
      contentTextStyle: TextStyle(
        color: RealtimeStyle.dark.text,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RealtimeStyle.dark.surfaceSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        borderSide: BorderSide(color: RealtimeStyle.dark.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        borderSide: BorderSide(color: RealtimeStyle.dark.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(RealtimeUiTokens.controlRadius),
        borderSide: BorderSide(color: RealtimeStyle.dark.primary, width: 1.5),
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
  Widget build(BuildContext context) {
    final style = RealtimeStyle.of(context);
    final isDark = style.isDark;
    return RepaintBoundary(
      child: ColoredBox(
        color: style.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: isDark
                      ? [
                          Positioned(
                            left: -110,
                            top: -130,
                            child: _AmbientOrb(
                              size: 380,
                              color: const Color(
                                0xFF1E1B4B,
                              ).withValues(alpha: 0.55),
                            ),
                          ),
                          Positioned(
                            right: -120,
                            top: 80,
                            child: _AmbientOrb(
                              size: 320,
                              color: const Color(
                                0xFF312E81,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          Positioned(
                            left: -60,
                            bottom: 120,
                            child: _AmbientOrb(
                              size: 290,
                              color: const Color(
                                0xFF0F2B48,
                              ).withValues(alpha: 0.45),
                            ),
                          ),
                          Positioned(
                            right: -110,
                            bottom: -140,
                            child: _AmbientOrb(
                              size: 400,
                              color: const Color(
                                0xFF1E293B,
                              ).withValues(alpha: 0.55),
                            ),
                          ),
                        ]
                      : const [
                          Positioned(
                            left: -110,
                            top: -130,
                            child: _AmbientOrb(
                              size: 380,
                              color: Color(0xFFD9E2FF),
                            ),
                          ),
                          Positioned(
                            right: -120,
                            top: 80,
                            child: _AmbientOrb(
                              size: 320,
                              color: Color(0xFFEDE9FE),
                            ),
                          ),
                          Positioned(
                            left: -60,
                            bottom: 120,
                            child: _AmbientOrb(
                              size: 290,
                              color: Color(0xFFE0F2FE),
                            ),
                          ),
                          Positioned(
                            right: -110,
                            bottom: -140,
                            child: _AmbientOrb(
                              size: 400,
                              color: Color(0xFFDBEAFE),
                            ),
                          ),
                        ],
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
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
