import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing browser provider assets return webSdkUnavailable', () async {
    if (!kIsWeb) return;

    await expectLater(
      ensureRealtimeProviderWebAssets(includeProductChat: true),
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.webSdkUnavailable,
        ),
      ),
    );
  });
}
