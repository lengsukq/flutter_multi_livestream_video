import 'package:flutter/material.dart';

/// Floats above the current route so tools can be moved off the drawing canvas.
/// Dragging moves the toolbar; a normal tap still reaches child buttons.
class MovableAnnotationToolbar extends StatefulWidget {
  const MovableAnnotationToolbar({
    super.key,
    required this.child,
    this.constrainToCanvas = false,
    this.startAtTop = true,
  });
  final Widget child;
  final bool constrainToCanvas;

  /// Screen-stage overlays should avoid covering the center gesture target.
  /// Full whiteboard views keep tools low to avoid top pagination controls.
  final bool startAtTop;
  @override
  State<MovableAnnotationToolbar> createState() =>
      _MovableAnnotationToolbarState();
}

class _MovableAnnotationToolbarState extends State<MovableAnnotationToolbar> {
  final _toolbar = GlobalKey();
  final _portal = OverlayPortalController();
  Offset? _overlayPosition;
  Offset _position = const Offset(1, 0);
  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) =>
      widget.constrainToCanvas || Overlay.maybeOf(context) == null
      ? _movable()
      : OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (context) {
            final view = View.of(context);
            final safe = EdgeInsets.fromViewPadding(
              view.viewPadding,
              view.devicePixelRatio,
            );
            final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
            Offset toOverlay(Offset global) {
              final box = Overlay.of(context).context.findRenderObject();
              return box is RenderBox ? box.globalToLocal(global) : global;
            }

            return CustomSingleChildLayout(
              delegate: _FloatingToolbarLayout(
                position: _overlayPosition,
                startAtTop: widget.startAtTop,
                padding:
                    safe.copyWith(
                      bottom: keyboard > safe.bottom ? keyboard : safe.bottom,
                    ) +
                    const EdgeInsets.all(8),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  key: _toolbar,
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (event) {
                    final box =
                        _toolbar.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (box == null || !box.hasSize) return;
                    setState(
                      () => _overlayPosition =
                          toOverlay(box.localToGlobal(Offset.zero)) +
                          event.delta,
                    );
                  },
                  child: widget.child,
                ),
              ),
            );
          },
          child: const SizedBox.expand(),
        );

  Widget _movable() => LayoutBuilder(
    builder: (context, constraints) {
      final bounds = constraints.biggest;
      return Align(
        alignment: Alignment(_position.dx * 2 - 1, _position.dy * 2 - 1),
        child: MouseRegion(
          cursor: SystemMouseCursors.move,
          child: GestureDetector(
            key: _toolbar,
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (event) {
              final box =
                  _toolbar.currentContext?.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              final travel = Size(
                bounds.width - box.size.width,
                bounds.height - box.size.height,
              );
              setState(
                () => _position = Offset(
                  travel.width > 0
                      ? (_position.dx + event.delta.dx / travel.width).clamp(
                          0,
                          1,
                        )
                      : _position.dx,
                  travel.height > 0
                      ? (_position.dy + event.delta.dy / travel.height).clamp(
                          0,
                          1,
                        )
                      : _position.dy,
                ),
              );
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bounds.width),
              child: widget.child,
            ),
          ),
        ),
      );
    },
  );
}

class _FloatingToolbarLayout extends SingleChildLayoutDelegate {
  _FloatingToolbarLayout({
    required this.position,
    required this.padding,
    required this.startAtTop,
  });
  final Offset? position;
  final EdgeInsets padding;
  final bool startAtTop;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          (constraints.maxWidth - padding.horizontal).clamp(
            0,
            constraints.maxWidth,
          ),
          (constraints.maxHeight - padding.vertical).clamp(
            0,
            constraints.maxHeight,
          ),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = (size.width - padding.right - childSize.width).clamp(
      padding.left,
      size.width,
    );
    final maxY = (size.height - padding.bottom - childSize.height).clamp(
      padding.top,
      size.height,
    );
    // The bottom placement does not obscure page actions on WhiteboardView.
    // Screen annotation tools instead start at the top to avoid intercepting
    // the center-of-video pen/highlighter gesture in landscape viewports.
    final desired =
        position ?? Offset(maxX, startAtTop ? padding.top : maxY - 96);
    return Offset(
      desired.dx.clamp(padding.left, maxX),
      desired.dy.clamp(padding.top, maxY),
    );
  }

  @override
  bool shouldRelayout(_FloatingToolbarLayout oldDelegate) => true;
}
