part of '../flutter_realtime_design_ui.dart';

/// A single light appearance with restrained green actions and glass navigation.
abstract final class RealtimeUiTheme {
  static ThemeData light({
    RealtimeUiThemeExtension appearance = const RealtimeUiThemeExtension(),
  }) {
    final palette = appearance.palette;
    final radius = BorderRadius.circular(appearance.controlRadius);
    final theme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
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
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.primary,
        selectionColor: palette.primary.withValues(alpha: .15),
        selectionHandleColor: palette.primary,
      ),
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.light(
        primary: palette.primary,
        onPrimary: palette.surface,
        secondary: palette.primaryAccent,
        onSecondary: palette.surface,
        surface: palette.surface,
        onSurface: palette.text,
        onSurfaceVariant: palette.textSecondary,
        primaryContainer: palette.primarySubtle,
        onPrimaryContainer: palette.text,
        secondaryContainer: palette.surfaceSubtle,
        onSecondaryContainer: palette.text,
        tertiary: palette.primary,
        onTertiary: palette.surface,
        tertiaryContainer: palette.surfaceSubtle,
        onTertiaryContainer: palette.text,
        surfaceContainerLow: palette.surface,
        surfaceContainer: palette.surfaceSubtle,
        surfaceContainerHigh: palette.surfaceSubtle,
        surfaceContainerHighest: palette.surfaceSubtle,
        outline: palette.borderStrong,
        outlineVariant: palette.border,
        error: palette.danger,
        onError: palette.surface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.surface,
          minimumSize: const Size(48, 48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: palette.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.text,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: palette.text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceSubtle,
        labelStyle: TextStyle(color: palette.textSecondary),
        hintStyle: TextStyle(color: palette.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide.none,
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
                ? palette.primary
                : palette.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            color: palette.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: palette.primarySubtle,
        selectedIconTheme: IconThemeData(color: palette.primary),
        unselectedIconTheme: IconThemeData(color: palette.textSecondary),
      ),
      dividerTheme: DividerThemeData(color: palette.border, thickness: 0.5),
      popupMenuTheme: PopupMenuThemeData(
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.text,
        contentTextStyle: TextStyle(color: palette.surface),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
    return theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        displaySmall: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: palette.text,
          letterSpacing: -0.8,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: palette.text,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: palette.text,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45, color: palette.text),
        bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: palette.text),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: palette.textSecondary,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
        ),
        labelSmall: TextStyle(fontSize: 13, color: palette.textSecondary),
      ),
    );
  }

  @Deprecated('The bundled appearance is light. Use light().')
  static ThemeData dark() => light();
}
