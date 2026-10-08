import 'package:flutter/material.dart';

/// Positions a toolbar inside its available canvas. Dragging any toolbar area
/// moves it; a normal tap is still delivered to child buttons.
class MovableAnnotationToolbar extends StatefulWidget {
  const MovableAnnotationToolbar({super.key, required this.child});
  final Widget child;
  @override
  State<MovableAnnotationToolbar> createState() =>
      _MovableAnnotationToolbarState();
}

class _MovableAnnotationToolbarState extends State<MovableAnnotationToolbar> {
  final _toolbar = GlobalKey();
  Offset _position = const Offset(1, 0);
  @override
  Widget build(BuildContext context) => LayoutBuilder(
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
