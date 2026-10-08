import 'package:flutter/material.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'annotation_surface.dart';
import 'whiteboard_view.dart';

/// Provider-neutral content surface. Camera/member rendering stays with the host.
class SharedContentStage extends StatelessWidget {
  const SharedContentStage({
    super.key,
    required this.mode,
    required this.whiteboard,
    this.members = const SizedBox.shrink(),
    this.screen,
    this.screenAnnotations,
    this.screenAspectRatio = 16 / 9,
    this.canAnnotateScreen = false,
  });
  final SharedContentMode mode;
  final WhiteboardSession whiteboard;
  final Widget members;
  final Widget? screen;
  final AnnotationController? screenAnnotations;
  final double screenAspectRatio;
  final bool canAnnotateScreen;
  @override
  Widget build(BuildContext context) => switch (mode) {
    SharedContentMode.members => members,
    SharedContentMode.whiteboard => WhiteboardView(session: whiteboard),
    SharedContentMode.screen =>
      screen == null
          ? const Center(child: Text('等待共享画面 / Waiting for shared screen'))
          : Center(
              child: AspectRatio(
                aspectRatio: screenAspectRatio,
                child: ClipRect(
                  child: screenAnnotations == null
                      ? screen!
                      : AnnotationSurface(
                          key: ValueKey(screenAnnotations!.canvas.canvasId),
                          session: screenAnnotations!,
                          allowEditing: canAnnotateScreen,
                          background: screen,
                        ),
                ),
              ),
            ),
  };
}
