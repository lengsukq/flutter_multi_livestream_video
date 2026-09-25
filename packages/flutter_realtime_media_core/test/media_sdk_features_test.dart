import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'advanced data validates capability limits before provider dispatch',
    () async {
      final session = _FeatureSession(
        capabilities: const MediaCapabilities(
          canSendData: true,
          maxDataMessageBytes: 4,
        ),
      );

      await session.sendData('ping');
      expect(session.sent.single, 'chat:ping');

      expect(
        () => session.sendData(
          'ping',
          options: const MediaSendOptions(targetParticipantIds: ['remote']),
        ),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
      expect(
        () => session.sendData('hello'),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidArgument,
          ),
        ),
      );
    },
  );

  test('advanced data can validate provider encoded envelope size', () async {
    final session = _SizedFeatureSession(
      capabilities: const MediaCapabilities(
        canSendData: true,
        maxDataMessageBytes: 8,
      ),
    );

    expect(
      () => session.sendData('ok'),
      throwsA(
        isA<MediaError>().having(
          (error) => error.code,
          'code',
          MediaErrorCode.invalidArgument,
        ),
      ),
    );
    expect(session.sent, isEmpty);
  });

  test(
    'device control is typed when a provider has no device surface',
    () async {
      final session = _FeatureSession();

      expect(
        () => session.listMediaDevices(),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
    },
  );

  test('stats surface is empty instead of fabricating provider metrics', () {
    final session = _FeatureSession();

    expect(session.connectionStats, isNull);
    expect(session.stats, emitsDone);
  });

  test('capability feature lookup covers the new SDK surfaces', () {
    const capabilities = MediaCapabilities(
      canEnumerateMicrophones: true,
      canSelectCamera: true,
      canReportNetworkStats: true,
      canTargetData: true,
      canListParticipants: true,
      canRemoveParticipants: true,
      canCloseRoom: true,
    );

    expect(capabilities.supports(MediaFeature.enumerateMicrophones), isTrue);
    expect(capabilities.supports(MediaFeature.selectCamera), isTrue);
    expect(capabilities.supports(MediaFeature.networkStats), isTrue);
    expect(capabilities.supports(MediaFeature.targetedData), isTrue);
    expect(capabilities.supports(MediaFeature.listParticipants), isTrue);
    expect(capabilities.supports(MediaFeature.removeParticipants), isTrue);
    expect(capabilities.supports(MediaFeature.closeRoom), isTrue);
  });
}

class _SizedFeatureSession extends _FeatureSession
    implements MediaDataPayloadSizer {
  _SizedFeatureSession({required super.capabilities});

  @override
  int dataPayloadSizeBytes(String message, MediaSendOptions options) =>
      message.length + options.topic.length + 8;
}

class _FeatureSession implements MediaSession, MediaDataMessenger {
  _FeatureSession({this.capabilities = const MediaCapabilities.none()});

  @override
  String get providerId => 'feature-test';

  @override
  MediaRole get role => MediaRole.participant;

  @override
  final MediaCapabilities capabilities;

  @override
  MediaSessionState get state => MediaSessionState.connected;

  @override
  MediaSnapshot get snapshot => MediaSnapshot(
    state: MediaSessionState.connected,
    role: role,
    capabilities: capabilities,
  );

  @override
  Stream<MediaSessionState> get states => const Stream.empty();

  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();

  @override
  Stream<MediaEvent> get events => const Stream.empty();

  final List<String> sent = [];

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    sent.add('$topic:$message');
  }

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {}

  @override
  Future<void> leave() async {}

  @override
  Future<void> dispose() async {}
}
