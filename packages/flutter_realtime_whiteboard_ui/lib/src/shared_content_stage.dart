import 'package:flutter/material.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'annotation_surface.dart';
import 'shared_content_stage_bar.dart';
import 'whiteboard_strings.dart';
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
    this.onStopSharing,
    this.screenSharerName,
  });
  final SharedContentMode mode;
  final WhiteboardSession whiteboard;
  final Widget members;
  final Widget? screen;
  final AnnotationController? screenAnnotations;
  final double screenAspectRatio;
  final bool canAnnotateScreen;
  final VoidCallback? onStopSharing;
  final String? screenSharerName;

  @override
  Widget build(BuildContext context) {
    final s = WhiteboardStrings.of(context);
    final style = RealtimeStyle.of(context);
    return switch (mode) {
      SharedContentMode.members => members,
      SharedContentMode.whiteboard => WhiteboardView(
        session: whiteboard,
        onStop: onStopSharing,
      ),
      SharedContentMode.screen =>
        screen == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onStopSharing != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: SharedContentStageBar(
                          title: s.t('screenShare'),
                          badgeIcon: Icons.screen_share_outlined,
                          subtitle: screenSharerName != null
                              ? '${s.zh ? '共享者' : 'Sharer'}: $screenSharerName'
                              : null,
                          onStop: onStopSharing,
                        ),
                      ),
                    const Text('等待共享画面 / Waiting for shared screen'),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    child: SharedContentStageBar(
                      title: s.t('screenShare'),
                      badgeIcon: Icons.screen_share_outlined,
                      subtitle: screenSharerName != null
                          ? '${s.zh ? '共享者' : 'Sharer'}: $screenSharerName'
                          : null,
                      canAnnotate:
                          canAnnotateScreen && screenAnnotations != null,
                      onStop: onStopSharing,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: screenAspectRatio,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1D1F),
                              borderRadius: BorderRadius.circular(
                                RealtimeUiThemeExtension.of(
                                  context,
                                ).stageRadius,
                              ),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.12),
                                width: 1,
                              ),
                              boxShadow: style.cardShadow,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                RealtimeUiThemeExtension.of(
                                  context,
                                ).stageRadius,
                              ),
                              child: screenAnnotations == null
                                  ? screen!
                                  : AnnotationSurface(
                                      key: ValueKey(
                                        screenAnnotations!.canvas.canvasId,
                                      ),
                                      session: screenAnnotations!,
                                      allowEditing: canAnnotateScreen,
                                      toolbarAtTop: false,
                                      constrainToolbarToCanvas: true,
                                      background: screen,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    };
  }
}
