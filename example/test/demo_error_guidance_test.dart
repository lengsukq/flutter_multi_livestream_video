import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_realtime_media_example/demo_strings.dart';

void main() {
  testWidgets('a duplicate room code gives actionable retry guidance', (
    tester,
  ) async {
    late String message;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: const [Locale('en')],
        home: Builder(
          builder: (context) {
            message = DemoStrings.of(context).displayRealtimeError(
              const RealtimeException(
                code: RealtimeErrorCode.roomConflict,
                message: 'Backend request failed (HTTP 409).',
                details: {'backendCode': 'room-exists'},
              ),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(message, contains('Room code already exists'));
    expect(message, contains('Join the existing room'));
  });
}
