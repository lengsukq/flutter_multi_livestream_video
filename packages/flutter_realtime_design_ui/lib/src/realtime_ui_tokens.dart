part of '../flutter_realtime_design_ui.dart';

/// Cool-gray product palette with a single amber action color.
///
/// Static constants are defaults; components that support host overrides read
/// [RealtimeStyle] or [RealtimeUiThemeExtension] instead.
abstract final class RealtimeUiTokens {
  // Surfaces
  static const background = Color(0xFFE9EDF2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF4F6F9);
  static const border = Color(0xFFDAE0E8);
  static const borderStrong = Color(0xFFC4CDDA);
  static const borderGlass = Color(0xE6FFFFFF);

  // Text
  static const text = Color(0xFF18202E);
  static const textSecondary = Color(0xFF3D4A5C);
  static const textMuted = Color(0xFF5B6678);

  // Accent and semantic
  static const accent = Color(0xFFF5C518);
  static const onAccent = Color(0xFF2A2100);
  static const accentSoft = Color(0x59F5C518);
  static const speak = Color(0xFF0E9E8E);
  static const live = Color(0xFFD93A3F);

  /// Accessible teal for small text and controls with white labels.
  static const speakStrong = Color(0xFF0B7F72);

  // Media and board
  static const canvasDark = Color(0xFF12161F);
  static const canvasDarkElevated = Color(0xFF181F2C);
  static const tile = Color(0xFFD5DCE6);
  static const tileStrong = Color(0xFFC4CDDA);
  static const board = Color(0xFFFCFDFE);
  static const boardGrid = Color(0xFFE7ECF2);
  static const boardInk = Color(0xFF1F2A3C);
  static const boardInkAccent = Color(0xFF2E6FD8);
  static const glassOverlay = Color(0xC2161B26);

  // Primary maps to the amber action color. Use [text] for colored copy on
  // light surfaces: amber text on white is not readable.
  static const primary = accent;
  static const primaryAccent = accent;
  static const primarySubtle = Color(0xFFFFF6D6);
  static const primaryBorder = Color(0xFFE9CE6A);
  static const onPrimary = onAccent;

  static const success = speakStrong;
  static const successSubtle = Color(0xFFEFFAF8);
  static const successBorder = Color(0xFFAEDFD8);
  static const warning = Color(0xFFB8791A);
  static const warningSubtle = Color(0xFFFFF4E5);
  static const danger = live;
  static const dangerSubtle = Color(0xFFFDECEC);
  static const dangerBorder = Color(0xFFF5C2C4);

  // Historical aliases kept for source compatibility.
  static const iosBlue = primary;
  static const iosGreen = speak;
  static const iosRed = danger;
  static const iosOrange = warning;
  static const iosIndigo = primary;
  static const iosTeal = speak;
  static const iosGray = textMuted;
  static const iosLightGray = border;
  static const appleTeal = speak;
  static const appleRose = danger;
  static const appleCrimson = danger;
  static const appleBlue = primary;
  static const appleIndigo = primary;
  static const appleDanger = danger;
  static const appleSuccess = speak;

  /// Shared radius hierarchy: cards, sheets and media stages stay soft; small
  /// controls keep a 12 pt squircle so dense toolbars stay calm.
  static const sheetRadius = 24.0;
  static const dockRadius = 16.0;
  static const cardRadius = 22.0;
  static const controlRadius = 12.0;
  static const compactRadius = 10.0;
  static const pillRadius = 999.0;
  static const radiusPill = pillRadius;
  static const radiusCard = cardRadius;

  static double segmentedOuterRadius({
    required double height,
    double preferredRadius = controlRadius,
  }) => preferredRadius > height / 2 ? preferredRadius : height / 2;

  static double segmentedThumbRadius({
    required double outerRadius,
    required double inset,
  }) => (outerRadius - inset).clamp(0.0, double.infinity);

  static const blur = 16.0;
  static const subtleBlur = 10.0;

  static const stageRadius = 18.0;
  static const mobileBodySize = 14.0;
  static const desktopBodySize = 14.0;
  static const auxiliaryTextSize = 12.0;
  static const titleSizes = [22.0, 28.0, 38.0];
  static const spacing = [4.0, 8.0, 12.0, 16.0, 24.0, 32.0];
  static const pagePadding = 20.0;
  static const sectionGap = 16.0;

  static const animFast = Duration(milliseconds: 160);
  static const animNormal = Duration(milliseconds: 240);
  static const animSlow = Duration(milliseconds: 340);

  static const primaryGradient = LinearGradient(
    colors: [accent, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glassGradient({
    double opacity = 0.94,
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
              0xFF1D1D1F,
            ).withValues(alpha: (opacity - 0.06).clamp(0.0, 0.96)),
          ]
        : [
            surface.withValues(alpha: (opacity + 0.04).clamp(0.0, 0.99)),
            surface.withValues(alpha: (opacity - 0.04).clamp(0.0, 0.98)),
          ],
  );

  static List<BoxShadow> get cardShadow => iosCardShadow;

  /// Soft directional elevation used by product cards and floating docks.
  static List<BoxShadow> get iosSoftShadow => [
    BoxShadow(
      color: const Color(0xFF101828).withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF101828).withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get iosCardShadow => iosSoftShadow;

  static List<BoxShadow> get iosDockShadow => [
    BoxShadow(
      color: const Color(0xFF101828).withValues(alpha: 0.10),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF101828).withValues(alpha: 0.05),
      blurRadius: 4,
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
      color: accent.withValues(alpha: .22),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Shared responsive breakpoints for built-in pages.
///
/// Pages must use these instead of repeating literals so phone, tablet and
/// desktop behave the same across meeting, live, chat and pre-join.
abstract final class RealtimeBreakpoints {
  static const double compactMaxWidth = 600;
  static const double tabletMinWidth = 600;
  static const double desktopMinWidth = 1000;
  static const double largeMinWidth = 1280;

  /// Accessibility guard: treat 165%+ text scaling as a narrower layout.
  static bool textScaleIsLarge(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(17) >= 28;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMaxWidth;

  static bool isTablet(double width) =>
      width >= tabletMinWidth && width < desktopMinWidth;

  static bool isDesktop(double width) =>
      width >= desktopMinWidth && !isLarge(width);

  static bool isLarge(double width) => width >= largeMinWidth;

  /// Desktop-class layout: enough width and a text size that still fits.
  static bool isWide(BuildContext context, double width) =>
      width >= desktopMinWidth && !textScaleIsLarge(context);

  static bool showsLabels(double width) => width >= largeMinWidth;
}
