part of '../flutter_realtime_design_ui.dart';

/// A reusable, provider-independent meeting stage with floating controls.
///
/// Pointer motion, presses, scrolling and keyboard input reveal the controls.
/// Only the controls fade; the stage (including clickable participants) stays
/// mounted and interactive. Set [autoHide] to false for touch-first layouts.
class RealtimeIdleControls extends StatefulWidget {
  const RealtimeIdleControls({
    super.key,
    required this.child,
    required this.controls,
    this.topControls,
    this.autoHide = true,
    this.autoHideTopControls = true,
    this.hideAfter = const Duration(seconds: 4),
    this.controlsBottom = 8,
    this.controlsMaxWidth = 800,
    this.reserveControlsSpace = false,
  });

  final Widget child;
  final Widget controls;

  /// Optional meeting header, faded by the same idle timer as the dock.
  final Widget? topControls;
  final bool autoHide;

  /// Keep persistent chrome (the room header) visible while the dock fades.
  final bool autoHideTopControls;
  final Duration hideAfter;
  final double controlsBottom;
  final double controlsMaxWidth;

  /// Lay controls below the stage instead of covering shared documents.
  /// Space stays reserved while controls fade so the content does not jump.
  final bool reserveControlsSpace;

  /// Whether controls should be shown inside a descendant stage overlay.
  /// Standalone stages without an idle container always show their actions.
  static bool controlsVisible(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_IdleControlsVisibility>()
          ?.visible ??
      true;

  @override
  State<RealtimeIdleControls> createState() => _RealtimeIdleControlsState();
}

class _IdleControlsVisibility extends InheritedWidget {
  const _IdleControlsVisibility({required this.visible, required super.child});

  final bool visible;

  @override
  bool updateShouldNotify(_IdleControlsVisibility oldWidget) =>
      visible != oldWidget.visible;
}

class _RealtimeIdleControlsState extends State<RealtimeIdleControls> {
  Timer? _idleTimer;
  bool _visible = true;
  bool _accessibleNavigation = false;
  final _topControlsFocus = FocusNode();
  final _controlsFocus = FocusNode();

  bool get _controlsHaveFocus =>
      _topControlsFocus.hasFocus || _controlsFocus.hasFocus;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accessibleNavigation = MediaQuery.accessibleNavigationOf(context);
    if (_accessibleNavigation) {
      _idleTimer?.cancel();
      _visible = true;
    } else {
      _scheduleHide();
    }
  }

  @override
  void didUpdateWidget(covariant RealtimeIdleControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoHide != widget.autoHide ||
        oldWidget.hideAfter != widget.hideAfter) {
      if (!widget.autoHide && !_visible) {
        _visible = true;
      }
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _idleTimer?.cancel();
    if (!widget.autoHide || _accessibleNavigation || _controlsHaveFocus) {
      return;
    }
    _idleTimer = Timer(widget.hideAfter, () {
      if (mounted && !_controlsHaveFocus) {
        setState(() => _visible = false);
      }
    });
  }

  void _reveal() {
    if (!_visible && mounted) setState(() => _visible = true);
    _scheduleHide();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _topControlsFocus.dispose();
    _controlsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hidden =
        widget.autoHide &&
        !_visible &&
        !MediaQuery.accessibleNavigationOf(context);
    final reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        !RealtimeUiThemeExtension.of(context).motionEnabled;
    final duration = reduceMotion ? Duration.zero : RealtimeUiTokens.animNormal;
    final controls = IgnorePointer(
      ignoring: hidden,
      child: AnimatedSlide(
        duration: duration,
        curve: Curves.easeOutCubic,
        offset: hidden ? const Offset(0, 0.25) : Offset.zero,
        child: AnimatedOpacity(
          duration: duration,
          opacity: hidden ? 0 : 1,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.controlsMaxWidth),
              child: _focusableControls(
                widget.controls,
                _controlsFocus,
                hidden,
              ),
            ),
          ),
        ),
      ),
    );
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, _) {
        _reveal();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: (_) => _reveal(),
        onPointerMove: (_) => _reveal(),
        onPointerDown: (_) => _reveal(),
        onPointerSignal: (_) => _reveal(),
        child: _IdleControlsVisibility(
          visible: !hidden,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.reserveControlsSpace)
                Column(
                  children: [
                    Expanded(child: widget.child),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        widget.controlsBottom,
                      ),
                      child: controls,
                    ),
                  ],
                )
              else
                widget.child,
              if (widget.topControls != null)
                Positioned(
                  top: 8,
                  left: 6,
                  right: 6,
                  child: IgnorePointer(
                    ignoring: hidden && widget.autoHideTopControls,
                    child: AnimatedSlide(
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      offset: hidden && widget.autoHideTopControls
                          ? const Offset(0, -0.25)
                          : Offset.zero,
                      child: AnimatedOpacity(
                        duration: duration,
                        opacity: hidden && widget.autoHideTopControls ? 0 : 1,
                        child: _focusableControls(
                          widget.topControls!,
                          _topControlsFocus,
                          hidden && widget.autoHideTopControls,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!widget.reserveControlsSpace)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: widget.controlsBottom,
                  child: controls,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _focusableControls(Widget child, FocusNode focus, bool hidden) =>
      Focus(
        focusNode: focus,
        canRequestFocus: false,
        onFocusChange: (_) => _reveal(),
        child: ExcludeFocus(
          excluding: hidden,
          child: ExcludeSemantics(excluding: hidden, child: child),
        ),
      );
}
