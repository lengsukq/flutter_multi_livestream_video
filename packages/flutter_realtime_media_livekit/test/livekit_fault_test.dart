import 'dart:async';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:flutter_realtime_media_livekit/flutter_realtime_media_livekit.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'real adapter disposes an injected room after connection failure',
    () async {
      final provider = _Room();
      final session = LiveKitInteractiveSession(roomFactory: () => provider);
      await expectLater(
        session.join(
          LiveKitJoinInfo(
            roomCode: 'r',
            participantId: 'p',
            role: MediaRole.participant,
            url: 'wss://example.invalid',
            token: 'test',
            identity: 'p',
          ),
        ),
        throwsA(isA<RealtimeException>()),
      );
      expect(provider.releases, 1);
      final first = session.dispose(), second = session.dispose();
      expect(identical(first, second), true);
      await first;
      expect(provider.releases, 1);
      expect(session.state, MediaSessionState.disposed);
    },
  );

  test('leave completes even when an in-flight join fails', () async {
    final provider = _Room();
    final session = LiveKitInteractiveSession(roomFactory: () => provider);
    final joining = session.join(_joinInfo());
    final leaving = session.leave();

    await expectLater(joining, throwsA(isA<RealtimeException>()));
    await leaving;
    expect(session.state, MediaSessionState.ended);
    expect(provider.releases, 1);
    await session.dispose();
  });

  test('leave is bounded and late join cannot revive a room', () async {
    final provider = _DeferredRoom();
    final session = LiveKitInteractiveSession(roomFactory: () => provider)
      ..cleanupTimeout = const Duration(milliseconds: 30);
    final joining = session.join(_joinInfo());
    // Attach the failure matcher before the deferred join completes.
    final joinFailure = expectLater(
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
    expect(provider.releases, 1);

    provider.finishConnect();
    await joinFailure;
    expect(session.state, MediaSessionState.ended);
    await session.dispose();
  });
}

class _DeferredRoom extends _Room {
  final Completer<void> _connect = Completer<void>();

  @override
  Future<void> connect(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    lk.RoomOptions? roomOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) => _connect.future;

  void finishConnect() => _connect.complete();
}

LiveKitJoinInfo _joinInfo() => LiveKitJoinInfo(
  roomCode: 'r',
  participantId: 'p',
  role: MediaRole.participant,
  url: 'wss://example.invalid',
  token: 'test',
  identity: 'p',
);

class _Room extends lk.Room {
  int releases = 0;
  @override
  Future<void> connect(
    String url,
    String token, {
    lk.ConnectOptions? connectOptions,
    lk.RoomOptions? roomOptions,
    lk.FastConnectOptions? fastConnectOptions,
  }) async {
    throw StateError('connect failure');
  }

  @override
  Future<bool> dispose() async {
    releases++;
    return super.dispose();
  }
}
