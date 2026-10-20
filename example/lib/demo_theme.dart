import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';

/// Authentic Tandem design system appearance, derived directly from:
/// - Tandem — Green room.html
/// - Tandem — Live classroom.html
/// - Tandem — Screen share and recording.html
abstract final class DemoTheme {
  // Tandem light palette
  static const Color background = Color(0xFFE9EDF2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF4F6F9);
  static const Color border = Color(0xFFDAE0E8);
  static const Color borderSubtle = Color(0xFFE7ECF2);
  static const Color borderStrong = Color(0xFFC4CDDA);

  static const Color text = Color(0xFF18202E);
  static const Color textSecondary = Color(0xFF3D4A5C);
  static const Color textMuted = Color(0xFF5B6678);

  static const Color accent = Color(0xFFF5C518);
  static const Color accentSoft = Color(0x59F5C518);
  static const Color accentInk = Color(0xFF2A2100);

  static const Color speak = Color(0xFF0E9E8E);
  static const Color speakStrong = Color(0xFF0B7F72);
  static const Color live = Color(0xFFD93A3F);

  static const Color tile = Color(0xFFD5DCE6);
  static const Color tileStrong = Color(0xFFC4CDDA);
  static const Color board = Color(0xFFFCFDFE);
  static const Color boardGrid = Color(0xFFE7ECF2);
  static const Color boardInk = Color(0xFF1F2A3C);
  static const Color boardInkAccent = Color(0xFF2E6FD8);

  static final RealtimeUiThemeExtension appearance = RealtimeUiThemeExtension(
    palette: RealtimeStyle.light.copyWith(
      background: background,
      surface: surface,
      surfaceSubtle: surfaceSubtle,
      border: border,
      borderSubtle: borderSubtle,
      borderStrong: borderStrong,
      text: text,
      textSecondary: textSecondary,
      textMuted: textMuted,
      primary: accent,
      primaryAccent: accent,
      primarySubtle: const Color(0xFFFFF6D6),
      primaryBorder: const Color(0xFFE9CE6A),
      accent: accent,
      onAccent: accentInk,
      accentSoft: accentSoft,
      speak: speak,
      speakStrong: speakStrong,
      live: live,
      cardShadow: const [
        BoxShadow(
          color: Color(0x0F101828),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    cardRadius: 18,
    controlRadius: 10,
    stageRadius: 16,
    sheetRadius: 22,
    bodyFontFamily: RealtimeFonts.body,
    displayFontFamily: RealtimeFonts.display,
  );

  static ThemeData themeData() => RealtimeUiTheme.light(appearance: appearance);
}
