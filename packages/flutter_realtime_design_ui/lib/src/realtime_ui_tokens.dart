part of '../flutter_realtime_design_ui.dart';

abstract final class RealtimeUiTokens {
  static const background = Color(0xFFF5F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF2F2F5);
  static const border = Color(0xFFE5E5EA);
  static const borderStrong = Color(0xFFC7C7CC);
  static const borderGlass = Color(0xF0FFFFFF);
  static const text = Color(0xFF1D1D1F);
  static const textMuted = Color(0xFF636366);

  // Historical color names remain aliases to the current accent palette.
  static const iosBlue = primary;
  static const iosGreen = Color(0xFF187A3D);
  static const iosRed = danger;
  static const iosOrange = Color(0xFFFF9500);
  static const iosIndigo = primary;
  static const iosTeal = primaryAccent;
  static const iosGray = Color(0xFF8E8E93);
  static const iosLightGray = Color(0xFFE5E5EA);

  static const appleTeal = primary;
  static const appleRose = danger;
  static const appleCrimson = danger;
  static const appleBlue = iosBlue;
  static const appleIndigo = iosIndigo;
  static const appleDanger = iosRed;
  static const appleSuccess = iosGreen;
  static const canvasDark = Color(
    0xFF12161F,
  ); // Immersive stage dark background
  static const canvasDarkElevated = Color(0xFF181F2C);
  static const glassOverlay = Color(0xC2161B26); // Frosted dark glass overlay

  static const primary = Color(0xFF187A3D);
  static const primaryAccent = Color(0xFF187A3D);
  static const primarySubtle = Color(0xFFEAF6EE);
  static const primaryBorder = Color(0xFFBFDFC8);
  static const success = Color(0xFF187A3D);
  static const successSubtle = Color(0xFFEAF9EE);
  static const successBorder = Color(0xFFA6EBB5);
  static const warning = Color(0xFFFF9500);
  static const warningSubtle = Color(0xFFFFF1E9);
  static const danger = Color(0xFFC52D42);
  static const dangerSubtle = Color(0xFFFEECEC);
  static const dangerBorder = Color(0xFFFECACA);

  /// Unified Apple HIG border radius hierarchy across the entire SDK.
  static const sheetRadius = 36.0;
  static const dockRadius = 999.0;
  static const cardRadius = 28.0;
  static const controlRadius = 20.0;
  static const compactRadius = 16.0;
  static const pillRadius = 999.0;
  static const radiusPill = pillRadius;
  static const radiusCard = cardRadius;

  /// A segmented control must round its outer track at least to half its
  /// height; the inset thumb then follows the same curve, minus the inset.
  /// This also honors a host's larger customized control radius.
  static double segmentedOuterRadius({
    required double height,
    double preferredRadius = controlRadius,
  }) => preferredRadius > height / 2 ? preferredRadius : height / 2;

  static double segmentedThumbRadius({
    required double outerRadius,
    required double inset,
  }) => (outerRadius - inset).clamp(0.0, double.infinity);

  static const blur = 24.0;
  static const subtleBlur = 12.0;

  static const stageRadius = 32.0;
  static const mobileBodySize = 17.0;
  static const desktopBodySize = 15.0;
  static const auxiliaryTextSize = 13.0;
  static const titleSizes = [22.0, 28.0, 34.0];
  static const spacing = [4.0, 8.0, 12.0, 16.0, 24.0, 32.0];
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
              0xFF1D1D1F,
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
      color: primary.withValues(alpha: .10),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];
}
