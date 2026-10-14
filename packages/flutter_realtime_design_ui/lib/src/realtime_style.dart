part of '../flutter_realtime_design_ui.dart';

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

  static const RealtimeStyle light = RealtimeStyle(
    isDark: false,
    background: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF2F2F5),
    surfaceGlass: Color(0xB8FFFFFF),
    border: Color(0xFFE5E5EA),
    borderSubtle: Color(0xFFF5F5F7),
    borderStrong: Color(0xFFC7C7CC),
    text: Color(0xFF1D1D1F),
    textSecondary: Color(0xFF48484A),
    textMuted: Color(0xFF636366),
    primary: Color(0xFF187A3D),
    primaryAccent: Color(0xFF187A3D),
    primarySubtle: Color(0xFFEAF6EE),
    primaryBorder: Color(0xFFBFDFC8),
    success: Color(0xFF187A3D), // Apple System Green
    successSubtle: Color(0xFFEAF9EE),
    warning: Color(0xFFFF9500), // Apple System Orange
    warningSubtle: Color(0xFFFFF1E9),
    danger: Color(0xFFC52D42),
    dangerSubtle: Color(0xFFFEECEC),
    cardShadow: [
      BoxShadow(color: Color(0x081D1D1F), blurRadius: 28, offset: Offset(0, 8)),
      BoxShadow(color: Color(0x041D1D1F), blurRadius: 12, offset: Offset(0, 2)),
    ],
    glassGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xD6FFFFFF), Color(0xB8FFFFFF)],
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
  );

  /// Compatibility alias; the bundled design has one appearance.
  @Deprecated('Use RealtimeStyle.light or a RealtimeUiThemeExtension override.')
  static const RealtimeStyle dark = light;

  static RealtimeStyle of(BuildContext context) =>
      RealtimeUiThemeExtension.of(context).palette;
}
