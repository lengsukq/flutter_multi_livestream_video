import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';
import 'annotation_canvas.dart';
import 'whiteboard_page.dart';

/// Only the active canvas is transmitted; repositories retain inactive pages.
class WhiteboardState {
  WhiteboardState({
    required this.revision,
    required this.canEdit,
    required List<WhiteboardPage> pages,
    required this.activePageId,
    required this.canvas,
    this.maxPages = 20,
  }) : pages = List.unmodifiable(pages);
  final int revision, maxPages;
  final bool canEdit;
  final List<WhiteboardPage> pages;
  final String activePageId;
  final AnnotationCanvas canvas;
  factory WhiteboardState.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => WhiteboardState._fromJsonUnchecked(value));
  factory WhiteboardState._fromJsonUnchecked(Map<String, dynamic> value) =>
      WhiteboardState(
        revision: JsonReader(value).optional<int>('revision') ?? 0,
        canEdit: JsonReader(value).optional<bool>('canEdit') ?? false,
        maxPages: JsonReader(value).optional<int>('maxPages') ?? 20,
        pages: JsonReader(
          value,
        ).objects('pages', WhiteboardPage.fromJson, optional: false),
        activePageId: JsonReader(value).required<String>('activePageId'),
        canvas: AnnotationCanvas.fromJson(
          Map<String, dynamic>.from(value['canvas'] as Map),
        ),
      );
}
