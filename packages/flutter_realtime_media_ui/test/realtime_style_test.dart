import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealtimeStyle theme adaptation and contrast', () {
    test('resolves light and dark styles from brightness', () {
      expect(RealtimeStyle.light.isDark, isFalse);
      expect(RealtimeStyle.light.isLight, isTrue);
      expect(RealtimeStyle.dark.isDark, isTrue);
      expect(RealtimeStyle.dark.isLight, isFalse);

      expect(RealtimeStyle.dark.text, const Color(0xFFFFFFFF));
      expect(RealtimeStyle.dark.background, const Color(0xFF0B0F19));
      expect(RealtimeStyle.light.background, const Color(0xFFF4F7FB));
    });

    test(
      'dark mode achieves WCAG AAA contrast ratio (> 7:1, targets > 12:1)',
      () {
        double relativeLuminance(Color c) {
          double channel(double v) => v <= 0.03928
              ? v / 12.92
              : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
          return 0.2126 * channel(c.r) +
              0.7152 * channel(c.g) +
              0.0722 * channel(c.b);
        }

        double contrastRatio(Color fg, Color bg) {
          final l1 = relativeLuminance(fg);
          final l2 = relativeLuminance(bg);
          final lighter = math.max(l1, l2);
          final darker = math.min(l1, l2);
          return (lighter + 0.05) / (darker + 0.05);
        }

        final dark = RealtimeStyle.dark;
        final textRatio = contrastRatio(dark.text, dark.background);
        final textSecondaryRatio = contrastRatio(
          dark.textSecondary,
          dark.background,
        );
        final textMutedRatio = contrastRatio(dark.textMuted, dark.background);

        // WCAG AAA requires at least 7:1 for normal text.
        // Our high-contrast design exceeds 15:1 for primary text, 11:1 for secondary, and 8:1 for muted text.
        expect(textRatio, greaterThan(15.0));
        expect(textSecondaryRatio, greaterThan(11.0));
        expect(textMutedRatio, greaterThan(8.0));
      },
    );

    testWidgets('RealtimeStyle.of resolves dynamically from BuildContext', (
      tester,
    ) async {
      RealtimeStyle? captured;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) {
              captured = RealtimeStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(captured?.isDark, isTrue);
      expect(captured?.text, const Color(0xFFFFFFFF));

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              captured = RealtimeStyle.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(captured?.isDark, isFalse);
      expect(captured?.text, const Color(0xFF0F172A));
    });

    testWidgets(
      'RealtimeGlassIconButton renders white icon in dark mode and dark icon in light mode',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RealtimeGlassIconButton(
                icon: Icons.language_rounded,
                tooltip: 'Lang',
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final darkIcon = tester.widget<Icon>(
          find.byIcon(Icons.language_rounded),
        );
        expect(darkIcon.color, const Color(0xFFFFFFFF));

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: RealtimeGlassIconButton(
                icon: Icons.language_rounded,
                tooltip: 'Lang',
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lightIcon = tester.widget<Icon>(
          find.byIcon(Icons.language_rounded),
        );
        expect(lightIcon.color, const Color(0xFF0F172A));
      },
    );

    testWidgets('RealtimePill renders high-contrast colors in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: RealtimePill(label: 'Test Pill', icon: Icons.info_outline),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(find.text('Test Pill'));
      expect(text.style?.color, RealtimeStyle.dark.textMuted);

      final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
      expect(icon.color, RealtimeStyle.dark.textMuted);
    });
  });
}
