part of '../flutter_realtime_design_ui.dart';

/// Bundled font families.
///
/// A font declared by a package is addressed as `packages/<package>/<family>`.
/// The single-package release rewrites these literals when it re-declares the
/// same files under `flutter_realtime_sdk`.
abstract final class RealtimeFonts {
  static const body = 'packages/flutter_realtime_design_ui/Onest';
  static const display =
      'packages/flutter_realtime_design_ui/BricolageGrotesque';

  /// Body family for the active theme; an empty host override means "use the
  /// platform default".
  static String bodyOf(BuildContext context) {
    final family = RealtimeUiThemeExtension.of(context).bodyFontFamily;
    return family ?? body;
  }

  static String displayOf(BuildContext context) {
    final family = RealtimeUiThemeExtension.of(context).displayFontFamily;
    return family ?? display;
  }
}

/// A single light appearance with an amber action color and calm gray surfaces.
abstract final class RealtimeUiTheme {
  static ThemeData light({
    RealtimeUiThemeExtension appearance = const RealtimeUiThemeExtension(
      glassEnabled: false,
    ),
  }) {
    final palette = appearance.palette;
    final radius = BorderRadius.circular(appearance.controlRadius);
    final bodyFamily = appearance.bodyFontFamily ?? RealtimeFonts.body;
    final displayFamily = appearance.displayFontFamily ?? RealtimeFonts.display;
    final theme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
      fontFamilyFallback: const [
        'PingFang SC',
        'Noto Sans CJK SC',
        'Microsoft YaHei',
        'Hiragino Sans GB',
      ],
      extensions: [appearance],
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: palette.primary,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
            fontSize: 14,
            color: palette.text,
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.text,
        selectionColor: palette.accent.withValues(alpha: .35),
        selectionHandleColor: palette.text,
      ),
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.light(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        secondary: palette.speakStrong,
        onSecondary: palette.surface,
        surface: palette.surface,
        onSurface: palette.text,
        onSurfaceVariant: palette.textMuted,
        primaryContainer: palette.primarySubtle,
        onPrimaryContainer: palette.onAccent,
        secondaryContainer: palette.surfaceSubtle,
        onSecondaryContainer: palette.text,
        tertiary: palette.speakStrong,
        onTertiary: palette.surface,
        tertiaryContainer: palette.successSubtle,
        onTertiaryContainer: palette.text,
        surfaceContainerLow: palette.surface,
        surfaceContainer: palette.surfaceSubtle,
        surfaceContainerHigh: palette.surfaceSubtle,
        surfaceContainerHighest: palette.border,
        outline: palette.borderStrong,
        outlineVariant: palette.border,
        error: palette.live,
        onError: palette.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.surface,
        foregroundColor: palette.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: displayFamily.isEmpty ? null : displayFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: palette.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.accent,
          foregroundColor: palette.onAccent,
          minimumSize: const Size(48, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appearance.controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appearance.controlRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appearance.controlRadius),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: palette.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSubtle,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14),
        labelStyle: TextStyle(color: palette.textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: palette.text, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appearance.sheetRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(appearance.sheetRadius),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(appearance.cardRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.primarySubtle,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.onAccent
                : palette.textMuted,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: palette.primarySubtle,
        selectedIconTheme: IconThemeData(color: palette.onAccent),
        unselectedIconTheme: IconThemeData(color: palette.textMuted),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 1),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.text,
        contentTextStyle: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          color: palette.surface,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
    return theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        displaySmall: TextStyle(
          fontFamily: displayFamily.isEmpty ? null : displayFamily,
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: palette.text,
          letterSpacing: -1.1,
          height: 1.1,
        ),
        headlineMedium: TextStyle(
          fontFamily: displayFamily.isEmpty ? null : displayFamily,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: palette.text,
          letterSpacing: -0.7,
          height: 1.15,
        ),
        headlineSmall: TextStyle(
          fontFamily: displayFamily.isEmpty ? null : displayFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: palette.text,
          letterSpacing: -0.4,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontFamily: displayFamily.isEmpty ? null : displayFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: palette.text,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontFamily: displayFamily.isEmpty ? null : displayFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: palette.text,
          letterSpacing: -0.1,
        ),
        titleSmall: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        bodyLarge: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          fontSize: 15,
          height: 1.45,
          color: palette.text,
        ),
        bodyMedium: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          fontSize: 14,
          height: 1.45,
          color: palette.text,
        ),
        bodySmall: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          fontSize: 12,
          height: 1.4,
          color: palette.textMuted,
        ),
        labelLarge: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        labelMedium: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.textMuted,
        ),
        labelSmall: TextStyle(
          fontFamily: bodyFamily.isEmpty ? null : bodyFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: palette.textMuted,
        ),
      ),
    );
  }

  @Deprecated('The bundled appearance is light. Use light().')
  static ThemeData dark() => light();
}
