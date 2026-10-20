import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_realtime_design_ui/flutter_realtime_design_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'desktop wheel and arrows scroll overflow participant thumbnails',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 340,
                child: RealtimeMeetingParticipantStrip(
                  participants: List.generate(
                    12,
                    (i) => RealtimeMeetingTileData(
                      id: 'member-$i',
                      displayName: 'Member $i',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      final scroll = list.controller!;
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      expect(scroll.offset, 0);
      expect(find.byTooltip('Next participants'), findsOneWidget);
      await tester.tap(find.byTooltip('Next participants'));
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      final beforeWheel = scroll.offset;
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(find.byType(ListView)),
          scrollDelta: const Offset(0, 240),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(beforeWheel));
      expect(find.byTooltip('Previous participants'), findsOneWidget);
      await tester.tap(find.byTooltip('Previous participants'));
      await tester.pumpAndSettle();
      expect(scroll.offset, lessThan(beforeWheel + 240));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'participant previews support keyboard selection and scrolling to remaining members',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: RealtimeMeetingParticipantStrip(
                  participants: List.generate(
                    10,
                    (i) => RealtimeMeetingTileData(
                      id: '$i',
                      displayName: 'Person $i',
                    ),
                  ),
                  onSelectParticipant: (p) => selected = p.id,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(selected, '0');
      final last = find.byKey(const ValueKey('meeting-participant-9'));
      await tester.drag(find.byType(ListView), const Offset(-1600, 0));
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(selected, '9');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hiding the filmstrip removes previews and expands the compact primary video',
    (tester) async {
      Widget page(bool visible) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              height: 500,
              child: RealtimeMeetingFilmstripStage(
                primaryParticipant: const RealtimeMeetingTileData(
                  id: 'a',
                  displayName: 'Main',
                ),
                participants: const [
                  RealtimeMeetingTileData(id: 'b', displayName: 'Other'),
                ],
                showFilmstrip: visible,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(true));
      expect(find.byType(RealtimeMeetingParticipantStrip), findsOneWidget);
      final oldRect = tester.getRect(find.text('Main'));
      await tester.pumpWidget(page(false));
      expect(find.byType(RealtimeMeetingParticipantStrip), findsNothing);
      expect(tester.getRect(find.text('Main')).top, greaterThan(oldRect.top));
      expect(tester.takeException(), isNull);
    },
  );
}
