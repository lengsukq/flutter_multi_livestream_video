part of '../flutter_realtime_design_ui.dart';

/// Runtime palette for the bundled cool-gray appearance.
///
/// Hosts can override individual colors through [copyWith] and install the
/// result in [RealtimeUiThemeExtension]. Components read this object instead of
/// static tokens whenever a host theme is possible.
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
    this.accent = RealtimeUiTokens.accent,
    this.onAccent = RealtimeUiTokens.onAccent,
    this.accentSoft = RealtimeUiTokens.accentSoft,
    this.speak = RealtimeUiTokens.speak,
    this.live = RealtimeUiTokens.live,
    this.speakStrong = RealtimeUiTokens.speakStrong,
    this.board = RealtimeUiTokens.board,
    this.boardGrid = RealtimeUiTokens.boardGrid,
    this.boardInk = RealtimeUiTokens.boardInk,
    this.tile = RealtimeUiTokens.tile,
    this.tileStrong = RealtimeUiTokens.tileStrong,
    this.successBorder = RealtimeUiTokens.successBorder,
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

  /// Amber action color: primary buttons, selected tools, badges.
  final Color accent;
  final Color onAccent;

  /// Translucent amber used for pinned notes and highlight blocks.
  final Color accentSoft;

  /// Speaking and "healthy" state (connection, live indicator).
  final Color speak;

  /// Teal ink and solid controls that meet 4.5:1 against white.
  final Color speakStrong;
  final Color live;
  final Color board;
  final Color boardGrid;
  final Color boardInk;
  final Color tile;
  final Color tileStrong;
  final Color successBorder;

  static const RealtimeStyle light = RealtimeStyle(
    isDark: false,
    background: RealtimeUiTokens.background,
    surface: RealtimeUiTokens.surface,
    surfaceSubtle: RealtimeUiTokens.surfaceSubtle,
    surfaceGlass: RealtimeUiTokens.borderGlass,
    border: RealtimeUiTokens.border,
    borderSubtle: RealtimeUiTokens.surfaceSubtle,
    borderStrong: RealtimeUiTokens.borderStrong,
    text: RealtimeUiTokens.text,
    textSecondary: RealtimeUiTokens.textSecondary,
    textMuted: RealtimeUiTokens.textMuted,
    primary: RealtimeUiTokens.accent,
    primaryAccent: RealtimeUiTokens.accent,
    primarySubtle: RealtimeUiTokens.primarySubtle,
    primaryBorder: RealtimeUiTokens.primaryBorder,
    success: RealtimeUiTokens.success,
    successSubtle: RealtimeUiTokens.successSubtle,
    warning: RealtimeUiTokens.warning,
    warningSubtle: RealtimeUiTokens.warningSubtle,
    danger: RealtimeUiTokens.live,
    dangerSubtle: RealtimeUiTokens.dangerSubtle,
    cardShadow: [
      BoxShadow(color: Color(0x10101828), blurRadius: 24, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
    ],
    glassGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFAFFFFFF), Color(0xF0FFFFFF)],
    ),
  );

  RealtimeStyle copyWith({
    bool? isDark,
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? surfaceGlass,
    Color? border,
    Color? borderSubtle,
    Color? borderStrong,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primaryAccent,
    Color? primarySubtle,
    Color? primaryBorder,
    Color? success,
    Color? successSubtle,
    Color? warning,
    Color? warningSubtle,
    Color? danger,
    Color? dangerSubtle,
    List<BoxShadow>? cardShadow,
    LinearGradient? glassGradient,
    Color? accent,
    Color? onAccent,
    Color? accentSoft,
    Color? speak,
    Color? speakStrong,
    Color? live,
    Color? board,
    Color? boardGrid,
    Color? boardInk,
    Color? tile,
    Color? tileStrong,
    Color? successBorder,
  }) => RealtimeStyle(
    isDark: isDark ?? this.isDark,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    surfaceGlass: surfaceGlass ?? this.surfaceGlass,
    border: border ?? this.border,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    borderStrong: borderStrong ?? this.borderStrong,
    text: text ?? this.text,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    primary: primary ?? this.primary,
    primaryAccent: primaryAccent ?? this.primaryAccent,
    primarySubtle: primarySubtle ?? this.primarySubtle,
    primaryBorder: primaryBorder ?? this.primaryBorder,
    success: success ?? this.success,
    successSubtle: successSubtle ?? this.successSubtle,
    warning: warning ?? this.warning,
    warningSubtle: warningSubtle ?? this.warningSubtle,
    danger: danger ?? this.danger,
    dangerSubtle: dangerSubtle ?? this.dangerSubtle,
    cardShadow: cardShadow ?? this.cardShadow,
    glassGradient: glassGradient ?? this.glassGradient,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    accentSoft: accentSoft ?? this.accentSoft,
    speak: speak ?? this.speak,
    speakStrong: speakStrong ?? this.speakStrong,
    live: live ?? this.live,
    board: board ?? this.board,
    boardGrid: boardGrid ?? this.boardGrid,
    boardInk: boardInk ?? this.boardInk,
    tile: tile ?? this.tile,
    tileStrong: tileStrong ?? this.tileStrong,
    successBorder: successBorder ?? this.successBorder,
  );

  /// Compatibility alias; the bundled design has one light appearance.
  @Deprecated('Use RealtimeStyle.light or a RealtimeUiThemeExtension override.')
  static const RealtimeStyle dark = light;

  static RealtimeStyle of(BuildContext context) =>
      RealtimeUiThemeExtension.of(context).palette;
}
