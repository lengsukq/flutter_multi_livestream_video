import 'dart:async';

import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

class _Media implements MediaSession {
  final lifecycle = StreamController<MediaSessionState>.broadcast();
  final notifications = StreamController<MediaEvent>.broadcast();
  @override
  String get providerId => 'test';
  @override
  Stream<MediaSessionState> get states => lifecycle.stream;
  @override
  Stream<MediaEvent> get events => notifications.stream;
  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SlowStartingPlugin extends _Plugin
    implements RealtimeStartingFeaturePlugin {
  _SlowStartingPlugin(super.id, super.log, {required super.gate});
  @override
  Future<void> start(Object feature) async {
    log.add('start:$id');
  }
}

class _SyncPlugin implements RealtimeFeaturePlugin {
  _SyncPlugin(this.id, this.log);
  @override
  final String id;
  final List<String> log;
  @override
  Object attach(RealtimeFeatureContext context) {
    log.add('attach:$id:${context.roomCode}');
    return id;
  }

  @override
  void detach(Object feature) => log.add('detach:$id');
}

class _Plugin implements RealtimeFeaturePlugin {
  _Plugin(this.id, this.log, {this.failure = false, this.gate});
  @override
  final String id;
  final List<String> log;
  final bool failure;
  final Completer<void>? gate;
  @override
  Future<Object> attach(RealtimeFeatureContext context) async {
    log.add('attach:$id:${context.roomCode}');
    await gate?.future;
    if (failure) throw StateError('broken $id');
    return id;
  }

  @override
  Future<void> detach(Object feature) async {
    log.add('detach:$id');
  }
}

void main() {
  late _Media media;
  late MediaRoomSession room;
  late RealtimeFeatureContext context;
  setUp(() {
    media = _Media();
    room = MediaRoomSession.direct(
      roomCode: 'demo-1',
      participantId: 'user-1',
      session: media,
    );
    context = RealtimeFeatureContext(
      media: room,
      interactions: () => throw StateError('not used'),
    );
  });

  test(
    'a pending slow plugin cannot hide or delay a following sync preset',
    () async {
      final log = <String>[];
      final gate = Completer<void>();
      final registry = RealtimeFeatureRegistry([
        _Plugin('slow', log, gate: gate),
        _SyncPlugin('classroom', log),
      ]);
      final initialization = registry.initialize(context);
      expect(registry.get<String>('classroom'), 'classroom');
      expect(registry.get<String>('slow'), isNull);
      await registry.dispose();
      gate.complete();
      await initialization;
      expect(log, [
        'attach:slow:demo-1',
        'attach:classroom:demo-1',
        'detach:classroom',
        'detach:slow',
      ]);
    },
  );
  test('late async feature starts once after ready sync presets', () async {
    final log = <String>[];
    final gate = Completer<void>();
    final registry = RealtimeFeatureRegistry([
      _SlowStartingPlugin('slow', log, gate: gate),
      _SyncPlugin('classroom', log),
    ]);
    final initialization = registry.initialize(context);
    await registry.startAttached();
    expect(registry.contains('classroom'), isTrue);
    expect(registry.contains('slow'), isFalse);
    gate.complete();
    await initialization;
    await registry.startAttached();
    expect(log.where((entry) => entry == 'start:slow'), hasLength(1));
    await registry.dispose();
  });
  tearDown(() async {
    await room.dispose();
    await media.lifecycle.close();
    await media.notifications.close();
  });

  test(
    'empty plugin set stays unloaded without creating extra sessions',
    () async {
      final registry = RealtimeFeatureRegistry(const []);
      await registry.initialize(context);
      expect(registry.registeredIds, isEmpty);
      expect(registry.activeIds, isEmpty);
      await registry.dispose();
      await registry.dispose();
    },
  );

  test(
    'attaches explicitly opted-in features and disposes in reverse order',
    () async {
      final log = <String>[];
      final registry = RealtimeFeatureRegistry([
        _Plugin('classroom', log),
        _Plugin('live', log),
      ]);
      await registry.initialize(context);
      expect(registry.get<String>('classroom'), 'classroom');
      expect(registry.get<String>('live'), 'live');
      expect(registry.get<int>('live'), isNull);
      await registry.dispose();
      expect(log, [
        'attach:classroom:demo-1',
        'attach:live:demo-1',
        'detach:live',
        'detach:classroom',
      ]);
    },
  );

  test('rejects duplicate IDs without starting any feature', () {
    expect(
      () => RealtimeFeatureRegistry([_Plugin('a', []), _Plugin('a', [])]),
      throwsArgumentError,
    );
  });

  test(
    'isolates attach failures and reports them without breaking other features',
    () async {
      final errors = <String>[];
      final registry = RealtimeFeatureRegistry([
        _Plugin('broken', [], failure: true),
        _Plugin('working', []),
      ], onError: (id, error, stack) => errors.add(id));
      await registry.initialize(context);
      expect(errors, ['broken']);
      expect(registry.contains('working'), isTrue);
      expect(registry.contains('broken'), isFalse);
      await registry.dispose();
    },
  );

  test(
    'late attach is released if room registry was disposed meanwhile',
    () async {
      final log = <String>[];
      final gate = Completer<void>();
      final registry = RealtimeFeatureRegistry([
        _Plugin('slow', log, gate: gate),
      ]);
      final initialization = registry.initialize(context);
      await Future<void>.delayed(Duration.zero);
      await registry.dispose();
      gate.complete();
      await initialization;
      expect(registry.activeIds, isEmpty);
      expect(log, ['attach:slow:demo-1', 'detach:slow']);
    },
  );
}
