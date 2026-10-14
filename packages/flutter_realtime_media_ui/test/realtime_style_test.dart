import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the legacy media entrypoint resolves the new shared light palette',
    (tester) async {
      RealtimeStyle? captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              captured = RealtimeStyle.of(context);
              return const RealtimeCardSurface(child: Text('Legacy import'));
            },
          ),
        ),
      );
      expect(captured, same(RealtimeStyle.light));
      expect(captured!.primary, RealtimeUiTokens.primary);
      expect(captured!.background, const Color(0xFFF5F5F7));
      expect(find.text('Legacy import'), findsOneWidget);
    },
  );
}
