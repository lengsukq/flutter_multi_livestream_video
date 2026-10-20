part of '../flutter_realtime_design_ui.dart';

/// Host overrides for the bundled cool-gray appearance.
///
/// Surfaces are opaque by default. Hosts can explicitly enable glass when
/// appropriate. These settings affect only UI, never a media or room session.
class RealtimeUiThemeExtension
    extends ThemeExtension<RealtimeUiThemeExtension> {
  const RealtimeUiThemeExtension({
    this.palette = RealtimeStyle.light,
    this.cardRadius = 22,
    this.controlRadius = 12,
    this.stageRadius = 18,
    this.sheetRadius = 24,
    this.blur = 16,
    this.glassOpacity = 0.94,
    this.glassEnabled = false,
    this.motionEnabled = true,
    this.bodyFontFamily,
    this.displayFontFamily,
  });

  final RealtimeStyle palette;
  final double cardRadius;
  final double controlRadius;
  final double stageRadius;
  final double sheetRadius;
  final double blur;
  final double glassOpacity;
  final bool glassEnabled;
  final bool motionEnabled;

  /// Bundled families. `null` keeps the package default; set an empty string to
  /// fall back to the host's platform font.
  final String? bodyFontFamily;
  final String? displayFontFamily;

  static RealtimeUiThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<RealtimeUiThemeExtension>() ??
      const RealtimeUiThemeExtension();

  Duration duration(BuildContext context, Duration value) =>
      !motionEnabled || MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : value;

  @override
  RealtimeUiThemeExtension copyWith({
    RealtimeStyle? palette,
    double? cardRadius,
    double? controlRadius,
    double? stageRadius,
    double? sheetRadius,
    double? blur,
    double? glassOpacity,
    bool? glassEnabled,
    bool? motionEnabled,
    String? bodyFontFamily,
    String? displayFontFamily,
  }) => RealtimeUiThemeExtension(
    palette: palette ?? this.palette,
    cardRadius: cardRadius ?? this.cardRadius,
    controlRadius: controlRadius ?? this.controlRadius,
    stageRadius: stageRadius ?? this.stageRadius,
    sheetRadius: sheetRadius ?? this.sheetRadius,
    blur: blur ?? this.blur,
    glassOpacity: glassOpacity ?? this.glassOpacity,
    glassEnabled: glassEnabled ?? this.glassEnabled,
    motionEnabled: motionEnabled ?? this.motionEnabled,
    bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
    displayFontFamily: displayFontFamily ?? this.displayFontFamily,
  );

  @override
  RealtimeUiThemeExtension lerp(RealtimeUiThemeExtension? other, double t) {
    if (other == null) return this;
    return copyWith(
      palette: t < 0.5 ? palette : other.palette,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t),
      stageRadius: lerpDouble(stageRadius, other.stageRadius, t),
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t),
      blur: lerpDouble(blur, other.blur, t),
      glassOpacity: lerpDouble(glassOpacity, other.glassOpacity, t),
      glassEnabled: t < 0.5 ? glassEnabled : other.glassEnabled,
      motionEnabled: t < 0.5 ? motionEnabled : other.motionEnabled,
      bodyFontFamily: t < 0.5 ? bodyFontFamily : other.bodyFontFamily,
      displayFontFamily: t < 0.5 ? displayFontFamily : other.displayFontFamily,
    );
  }
}
