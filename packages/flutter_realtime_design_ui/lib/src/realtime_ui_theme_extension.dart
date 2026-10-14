part of '../flutter_realtime_design_ui.dart';

/// Host overrides for the bundled pearl-light appearance.
///
/// Disable glass when a platform cannot report Reduce Transparency. These
/// settings affect only the optional UI, never a media or room session.
class RealtimeUiThemeExtension
    extends ThemeExtension<RealtimeUiThemeExtension> {
  const RealtimeUiThemeExtension({
    this.palette = RealtimeStyle.light,
    this.cardRadius = 28,
    this.controlRadius = 20,
    this.stageRadius = 32,
    this.sheetRadius = 36,
    this.blur = 24,
    this.glassOpacity = 0.78,
    this.glassEnabled = true,
    this.motionEnabled = true,
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
    );
  }
}
