// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://docs.flutter.dev/cookbook/testing/integration/introduction

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_multi_livestream_video_chime/flutter_multi_livestream_video_chime.dart';
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Chime adapter session is available on the host device', (
    WidgetTester tester,
  ) async {
    final session = ChimeMediaSession();
    expect(session.state, MediaSessionState.idle);
    await session.dispose();
    expect(session.state, MediaSessionState.disposed);
  });
}
