import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'annotation_canvas.dart';
import 'shared_content_mode.dart';
import 'whiteboard_state.dart';

class SharedContentState {
  const SharedContentState({
    required this.mode,
    required this.whiteboard,
    required this.screen,
    required this.canManage,
    this.revision = 0,
  });
  final SharedContentMode mode;
  final WhiteboardState whiteboard;
  final AnnotationCanvas screen;
  final bool canManage;
  final int revision;
  factory SharedContentState.fromJson(Map<String, dynamic> value) => JsonReader(
    value,
  ).decode(() => SharedContentState._fromJsonUnchecked(value));
  factory SharedContentState._fromJsonUnchecked(Map<String, dynamic> value) =>
      SharedContentState(
        revision: JsonReader(value).optional<int>('revision') ?? 0,
        mode: JsonReader(value).enumValue('mode', SharedContentMode.values),
        canManage: JsonReader(value).optional<bool>('canManage') ?? false,
        whiteboard: WhiteboardState.fromJson(
          Map<String, dynamic>.from(value['whiteboard'] as Map),
        ),
        screen: AnnotationCanvas.fromJson(
          Map<String, dynamic>.from(value['screen'] as Map),
        ),
      );
}
