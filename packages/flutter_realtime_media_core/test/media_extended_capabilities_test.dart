import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extended SDK capabilities', () {
    test('device helpers filter and select provider-neutral devices', () async {
      final session = _ExtendedSession();

      final microphones = await session.listMicrophones();
      final cameras = await session.listCameras();
      final outputs = await session.listAudioOutputs();

      expect(microphones.map((item) => item.id), ['mic-1']);
      expect(cameras.map((item) => item.id), ['camera-1']);
      expect(outputs.map((item) => item.id), ['speaker-1']);

      await session.selectMicrophone(microphones.single);
      await session.selectCamera(cameras.single);
      await session.selectAudioOutput(outputs.single);
      expect(session.selected, ['mic-1', 'camera-1', 'speaker-1']);

      await expectLater(
        session.selectCamera(microphones.single),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidArgument,
          ),
        ),
      );
    });

    test('unsupported device helpers fail with a typed error', () async {
      final session = _BareSession();

      await expectLater(
        session.listMicrophones(),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
      await expectLater(
        session.selectAudioOutput(
          const MediaDevice(
            id: 'speaker-1',
            label: 'Speaker',
            kind: MediaDeviceKind.audioOutput,
          ),
        ),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
    });

    test(
      'network statistics expose current value, stream, and feature flag',
      () async {
        final session = _ExtendedSession();
        final received = <MediaConnectionStats>[];
        final subscription = session.stats.listen(received.add);

        expect(
          session.capabilities.supports(MediaFeature.networkStats),
          isTrue,
        );
        expect(session.connectionStats?.rttMs, 42);
        await Future<void>.delayed(Duration.zero);
        expect(received.single.downloadKbps, 2400);

        await subscription.cancel();
      },
    );

    test('advanced data feature flags remain independently queryable', () {
      const capabilities = MediaCapabilities(
        canSendData: true,
        canTargetData: true,
        canSendUnreliableData: true,
        maxDataMessageBytes: 4096,
      );

      expect(capabilities.supports(MediaFeature.sendData), isTrue);
      expect(capabilities.supports(MediaFeature.targetedData), isTrue);
      expect(capabilities.supports(MediaFeature.unreliableData), isTrue);
      expect(capabilities.supports(MediaFeature.unorderedData), isFalse);
      expect(capabilities.maxDataMessageBytes, 4096);
    });
  });
}

class _BareSession implements MediaSession {
  static const _capabilities = MediaCapabilities.none();

  @override
  MediaCapabilities get capabilities => _capabilities;

  @override
  Stream<MediaEvent> get events => const Stream.empty();

  @override
  String get providerId => 'fake';

  @override
  MediaRole get role => MediaRole.participant;

  @override
  MediaSnapshot get snapshot => MediaSnapshot(
    state: MediaSessionState.connected,
    capabilities: capabilities,
  );

  @override
  Stream<MediaSnapshot> get snapshots => const Stream.empty();

  @override
  MediaSessionState get state => MediaSessionState.connected;

  @override
  Stream<MediaSessionState> get states => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {}

  @override
  Future<void> leave() async {}
}

class _ExtendedSession extends _BareSession
    implements MediaDeviceController, MediaStatsProvider {
  static const _extendedCapabilities = MediaCapabilities(
    canEnumerateAudioDevices: true,
    canEnumerateMicrophones: true,
    canEnumerateCameras: true,
    canSelectMicrophone: true,
    canSelectCamera: true,
    canSelectAudioOutput: true,
    canReportNetworkStats: true,
  );

  static const _connectionStats = MediaConnectionStats(
    timestampMs: 1,
    upstreamQuality: MediaNetworkQuality.good,
    downstreamQuality: MediaNetworkQuality.excellent,
    rttMs: 42,
    uploadKbps: 1200,
    downloadKbps: 2400,
  );

  final List<String> selected = [];

  @override
  MediaCapabilities get capabilities => _extendedCapabilities;

  @override
  MediaConnectionStats? get connectionStats => _connectionStats;

  @override
  Stream<MediaConnectionStats> get stats => Stream.value(_connectionStats);

  @override
  Future<List<MediaDevice>> listMediaDevices({
    Set<MediaDeviceKind>? kinds,
  }) async {
    const devices = [
      MediaDevice(
        id: 'mic-1',
        label: 'Microphone',
        kind: MediaDeviceKind.microphone,
      ),
      MediaDevice(
        id: 'camera-1',
        label: 'Camera',
        kind: MediaDeviceKind.camera,
      ),
      MediaDevice(
        id: 'speaker-1',
        label: 'Speaker',
        kind: MediaDeviceKind.audioOutput,
      ),
    ];
    if (kinds == null) return devices;
    return devices.where((device) => kinds.contains(device.kind)).toList();
  }

  @override
  Future<void> selectMediaDevice(MediaDevice device) async {
    selected.add(device.id);
  }
}
