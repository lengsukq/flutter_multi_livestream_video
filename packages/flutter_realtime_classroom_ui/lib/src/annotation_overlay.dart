import 'package:flutter/material.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';
import 'classroom_strings.dart';
export 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart'
    show AnnotationPainter;

/// Compatibility adapter for the legacy screen annotation session.
class ClassroomAnnotationOverlay extends StatelessWidget {
  const ClassroomAnnotationOverlay({
    super.key,
    required this.session,
    required this.participantId,
    this.localShare = false,
  });
  final AnnotationSession session;
  final String participantId;
  final bool localShare;
  @override
  Widget build(BuildContext context) => StreamBuilder<AnnotationCanvas>(
    stream: session.canvases,
    initialData: session.canvas,
    builder: (context, snapshot) =>
        snapshot.data?.participantId == participantId
        ? AnnotationSurface(
            session: session,
            allowEditing: localShare,
            enableNavigation: false,
            editTooltip: ClassroomStrings.of(context).t('annotate'),
          )
        : const SizedBox.shrink(),
  );
}
