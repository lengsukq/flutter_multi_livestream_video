import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' as agora;
import 'package:flutter_realtime_media_agora/flutter_realtime_media_agora.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leaving during Agora initialization cancels late join', () async {
    final engine = _DeferredEngine();
    final session = AgoraInteractiveSession(engineFactory: () => engine);
    final info = AgoraJoinInfo.fromBackendResponse({
      'provider': 'agora',
      'roomCode': 'r',
      'agora': {'appId': 'app', 'channelName': 'r', 'token': 'test', 'uid': 1},
    });
    final joining = session.join(info);
    final cancellation = expectLater(
      joining,
      throwsA(
        isA<RealtimeException>().having(
          (error) => error.code,
          'code',
          RealtimeErrorCode.cancelled,
        ),
      ),
    );
    await session.leave().timeout(const Duration(seconds: 2));
    expect(session.state, MediaSessionState.ended);
    engine.completeInitialization();
    await cancellation;
    expect(session.state, MediaSessionState.ended);
    expect(engine.releases, 1);
    await session.dispose();
  });

  test(
    'real adapter releases an injected engine after initialization failure',
    () async {
      final engine = _Engine();
      final session = AgoraInteractiveSession(engineFactory: () => engine);
      final info = AgoraJoinInfo.fromBackendResponse({
        'provider': 'agora',
        'roomCode': 'r',
        'agora': {
          'appId': 'app',
          'channelName': 'r',
          'token': 'test',
          'uid': 1,
        },
      });
      await expectLater(session.join(info), throwsA(isA<RealtimeException>()));
      expect(engine.releases, 1);
      final first = session.dispose(), second = session.dispose();
      expect(identical(first, second), true);
      await first;
      expect(engine.releases, 1);
      expect(session.state, MediaSessionState.disposed);
    },
  );
}

class _DeferredEngine extends _Engine {
  final Completer<void> _initialization = Completer<void>();

  @override
  Future<void> initialize(agora.RtcEngineContext context) =>
      _initialization.future;

  void completeInitialization() => _initialization.complete();
}

class _Engine extends Fake implements agora.RtcEngine {
  int releases = 0;
  @override
  Future<void> initialize(agora.RtcEngineContext context) async {
    throw StateError('initialize failure');
  }

  @override
  Future<void> release({bool sync = false}) async {
    releases++;
  }
}
