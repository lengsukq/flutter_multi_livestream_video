part of '../flutter_realtime_design_ui.dart';

class RealtimeGlassPressable extends StatefulWidget {
  const RealtimeGlassPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this._borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final double? _borderRadius;
  double get borderRadius => _borderRadius ?? RealtimeUiTokens.controlRadius;

  @override
  State<RealtimeGlassPressable> createState() => _RealtimeGlassPressableState();
}

class _RealtimeGlassPressableState extends State<RealtimeGlassPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.disableAnimationsOf(context) ||
        !RealtimeUiThemeExtension.of(context).motionEnabled;
    Widget scaled = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (!disableAnimations) _setPressed(true);
        unawaited(HapticFeedback.lightImpact());
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: (_pressed && !disableAnimations) ? widget.pressedScale : 1.0,
        duration: RealtimeUiThemeExtension.of(
          context,
        ).duration(context, RealtimeUiTokens.animFast),
        curve: Curves.easeOutBack,
        child: widget.child,
      ),
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      final radius =
          widget._borderRadius ??
          RealtimeUiThemeExtension.of(context).controlRadius;
      scaled = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: scaled,
        ),
      );
    }

    return scaled;
  }
}
