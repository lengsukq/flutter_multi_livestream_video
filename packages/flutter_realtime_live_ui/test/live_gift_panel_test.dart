import 'package:flutter/material.dart';
import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'package:flutter_realtime_live_ui/flutter_realtime_live_ui.dart';
import 'package:flutter_test/flutter_test.dart';

class Repository implements LiveInteractionRepository {
  @override
  Future<LiveInteractionState> sendLike({required String eventId}) =>
      snapshot();
  final ids = <String>[];
  bool fail = true;
  @override
  Future<LiveInteractionState> snapshot() async => LiveInteractionState(
    roomCode: 'live1',
    revision: 0,
    selfUserId: 'alice',
    recipientId: 'host',
    canSendGift: true,
    catalog: [LiveGift(id: 'star', name: 'Star', icon: 'star')],
  );
  @override
  Future<LiveInteractionState> sendGift(
    String giftId,
    int quantity, {
    required String eventId,
  }) {
    ids.add(eventId);
    if (fail) throw StateError('Try again');
    return snapshot();
  }

  @override
  void close() {}
}

class _RateLimitedRepository extends Repository {
  int sends = 0;

  @override
  Future<LiveInteractionState> sendGift(
    String giftId,
    int quantity, {
    required String eventId,
  }) {
    sends++;
    throw const RealtimeException(
      code: RealtimeErrorCode.serverError,
      statusCode: 429,
      message: 'Gift combo paused',
    );
  }
}

void main() {
  testWidgets(
    '429 shows a temporary readable cooldown rather than raw API error',
    (tester) async {
      final repository = _RateLimitedRepository();
      final session = LiveInteractionSession(
        repository,
        pollInterval: const Duration(hours: 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveGiftPanel(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Star × 1'));
      await tester.pump();
      expect(find.textContaining('cooling down'), findsOneWidget);
      expect(find.textContaining('429'), findsNothing);
      await tester.tap(find.text('Star × 1'));
      await tester.pump();
      expect(repository.sends, 1);
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.textContaining('cooling down'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.dispose();
    },
  );
  testWidgets('gift panel retries the same event id and fits a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = Repository();
    final session = LiveInteractionSession(
      repository,
      pollInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LiveGiftPanel(session: session)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Star × 1'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.ids[0], repository.ids[1]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await session.dispose();
  });

  testWidgets(
    'gift panel switches quantity multiplier and triggers close callback',
    (tester) async {
      final repository = Repository();
      repository.fail = false;
      final session = LiveInteractionSession(
        repository,
        pollInterval: const Duration(hours: 1),
      );
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LiveGiftPanel(
              session: session,
              showHeader: true,
              onClose: () => closed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Send a gift'), findsOneWidget);
      expect(find.text('Star × 1'), findsOneWidget);

      await tester.tap(find.text('×5'));
      await tester.pumpAndSettle();
      expect(find.text('Star × 5'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await session.dispose();
    },
  );
}
