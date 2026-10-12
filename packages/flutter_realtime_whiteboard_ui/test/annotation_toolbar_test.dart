import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_whiteboard_core/flutter_realtime_whiteboard_core.dart';
import 'package:flutter_realtime_whiteboard_ui/flutter_realtime_whiteboard_ui.dart';

void main() {
  testWidgets('AnnotationToolbar renders tools and dispatches callbacks', (
    tester,
  ) async {
    AnnotationTool currentTool = AnnotationTool.pen;
    var drawing = true;
    var undos = 0;
    var clears = 0;
    var closes = 0;

    Widget buildToolbar() => MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return AnnotationToolbar(
              tool: currentTool,
              drawingEnabled: drawing,
              onToolChanged: (tool) => setState(() => currentTool = tool),
              onDrawingToggle: () => setState(() => drawing = !drawing),
              onUndo: () => undos++,
              onClear: () => clears++,
              onClose: () => closes++,
            );
          },
        ),
      ),
    );

    await tester.pumpWidget(buildToolbar());
    await tester.pumpAndSettle();

    // Verify all tool buttons are present
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.highlight), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.arrow_outward), findsOneWidget);
    expect(find.byIcon(Icons.text_fields), findsOneWidget);
    expect(find.byIcon(Icons.undo), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Switch tool to highlight
    await tester.tap(find.byIcon(Icons.highlight));
    await tester.pumpAndSettle();
    expect(currentTool, AnnotationTool.highlight);

    // Switch tool to circle
    await tester.tap(find.byIcon(Icons.circle_outlined));
    await tester.pumpAndSettle();
    expect(currentTool, AnnotationTool.circle);

    // Trigger undo, clear, close
    await tester.tap(find.byIcon(Icons.undo));
    expect(undos, 1);
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    expect(clears, 1);
    await tester.tap(find.byIcon(Icons.close));
    expect(closes, 1);

    // Toggle drawing off -> switches to pan icon and hides drawing tools
    await tester.tap(find.byIcon(Icons.draw_outlined));
    await tester.pumpAndSettle();
    expect(drawing, false);
    expect(find.byIcon(Icons.pan_tool_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
  });

  testWidgets(
    'AnnotationToolbar fixedTop layout renders color swatches and keeps tools visible',
    (tester) async {
      AnnotationTool currentTool = AnnotationTool.pen;
      var selectedColor = 0xff1e293b;
      var drawing = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AnnotationToolbar(
                  tool: currentTool,
                  fixedTop: true,
                  showDragHandle: false,
                  drawingEnabled: drawing,
                  selectedColor: selectedColor,
                  onColorChanged: (c) => setState(() => selectedColor = c),
                  onToolChanged: (tool) => setState(() => currentTool = tool),
                  onDrawingToggle: () => setState(() => drawing = !drawing),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No drag handle in fixed top mode
      expect(find.byIcon(Icons.drag_indicator), findsNothing);

      // In fixedTop mode, tools are visible even when drawing is not yet enabled
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.highlight), findsOneWidget);
      expect(find.byTooltip('Color'), findsWidgets);

      // Tap red color (0xffdc2626)
      final redBox = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xffdc2626),
      );
      expect(redBox, findsOneWidget);
      await tester.tap(redBox);
      await tester.pumpAndSettle();
      expect(selectedColor, 0xffdc2626);
    },
  );

  testWidgets(
    'palette button opens color picker dialog and applies selected color',
    (tester) async {
      int selectedColor = 0xff1e293b;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AnnotationToolbar(
                  tool: AnnotationTool.pen,
                  fixedTop: true,
                  selectedColor: selectedColor,
                  onColorChanged: (c) => setState(() => selectedColor = c),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap palette button
      await tester.tap(find.byIcon(Icons.palette_outlined));
      await tester.pumpAndSettle();

      // Dialog is shown
      expect(find.byType(WhiteboardColorPickerDialog), findsOneWidget);

      // Select cyan (0xff06b6d4) from the dialog presets
      final cyanBox = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color == const Color(0xff06b6d4),
      );
      expect(cyanBox, findsOneWidget);
      await tester.tap(cyanBox);
      await tester.pump();

      // Tap confirm button
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Dialog is dismissed and color is updated
      expect(find.byType(WhiteboardColorPickerDialog), findsNothing);
      expect(selectedColor, 0xff06b6d4);
    },
  );
}
