import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider display names keep known brands readable', () {
    expect(mediaProviderDisplayName('livekit'), 'LiveKit');
    expect(mediaProviderDisplayName('trtc'), 'Tencent TRTC');
    expect(mediaProviderDisplayName('aws'), 'AWS');
    expect(mediaProviderDisplayName('chime'), 'AWS · Chime');
    expect(mediaProviderDisplayName('ivs'), 'AWS · IVS');
    expect(mediaProviderDisplayName('custom'), 'CUSTOM');
  });

  testWidgets('ready result exposes continue action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaPreJoinDialog(
          runCheck: () async => const MediaPreJoinResult(
            role: MediaRole.participant,
            providerId: 'fake',
            checks: [
              MediaPreJoinCheck(
                type: MediaPreJoinCheckType.backend,
                status: MediaPreJoinStatus.passed,
                severity: MediaPreJoinSeverity.blocking,
                message: 'Backend reachable.',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ready to continue'), findsOneWidget);
    expect(find.text('FAKE'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Run again'), findsOneWidget);
  });

  testWidgets('blocking result hides continue action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaPreJoinDialog(
          runCheck: () async => const MediaPreJoinResult(
            role: MediaRole.participant,
            checks: [
              MediaPreJoinCheck(
                type: MediaPreJoinCheckType.backend,
                status: MediaPreJoinStatus.failed,
                severity: MediaPreJoinSeverity.blocking,
                message: 'Backend unavailable.',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Resolve blocking issues before joining'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('pre-join UI follows zh-CN host locale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: RealtimeStrings.supportedLocales,
        localizationsDelegates: RealtimeStrings.localizationsDelegates,
        home: MediaPreJoinDialog(
          runCheck: () async => const MediaPreJoinResult(
            role: MediaRole.participant,
            checks: [
              MediaPreJoinCheck(
                type: MediaPreJoinCheckType.backend,
                status: MediaPreJoinStatus.passed,
                severity: MediaPreJoinSeverity.blocking,
                message: 'Backend reachable.',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('加入前检查'), findsOneWidget);
    expect(find.text('可以继续'), findsOneWidget);
    expect(find.text('后端'), findsOneWidget);
    expect(find.text('通过'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);
    expect(find.text('重新检查'), findsOneWidget);
  });
}
