import 'dart:async';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_media_session.dart';

/// A viewer session built from the viewer interface alone.
///
/// If `BroadcastViewerSession` ever grew a publish method (mute, camera,
/// switchCamera, ...), this class would stop compiling. That is the compile-time
/// half of the broadcast guarantee.
class _ViewerOnlySession implements BroadcastViewerSession {
  final _stateController = StreamController<MediaSessionState>.broadcast();
  final _snapshotController = StreamController<MediaSnapshot>.broadcast();
  final _eventController = StreamController<MediaEvent>.broadcast();

  MediaSnapshot _snapshot = MediaSnapshot(role: MediaRole.viewer);
  final List<String> sentMessages = [];

  @override
  String get providerId => 'fake';

  @override
  MediaRole get role => MediaRole.viewer;

  @override
  MediaCapabilities get capabilities =>
      const MediaCapabilities.broadcastViewer();

  @override
  MediaSessionState get state => _snapshot.state;

  @override
  MediaSnapshot get snapshot => _snapshot;

  @override
  Stream<MediaSessionState> get states => _stateController.stream;

  @override
  Stream<MediaSnapshot> get snapshots => _snapshotController.stream;

  @override
  Stream<MediaEvent> get events => _eventController.stream;

  @override
  Future<void> join(MediaJoinInfo joinInfo) async {
    _snapshot = _snapshot.copyWith(
      state: MediaSessionState.connected,
      role: MediaRole.viewer,
      localParticipantId: joinInfo.participantId,
    );
    _stateController.add(MediaSessionState.connected);
  }

  @override
  Future<void> leave() async {
    _snapshot = _snapshot.copyWith(state: MediaSessionState.ended);
    _stateController.add(MediaSessionState.ended);
  }

  @override
  Future<void> dispose() async {
    _snapshot = _snapshot.copyWith(state: MediaSessionState.disposed);
    await _stateController.close();
    await _snapshotController.close();
    await _eventController.close();
  }

  @override
  Future<void> sendMessage(String message, {String topic = 'chat'}) async {
    sentMessages.add('$topic:$message');
  }
}

void main() {
  group('MediaRole', () {
    test('viewer may not publish media; other roles may', () {
      expect(MediaRole.viewer.canPublishMedia, isFalse);
      expect(MediaRole.participant.canPublishMedia, isTrue);
      expect(MediaRole.host.canPublishMedia, isTrue);
    });

    test('parses wire names and rejects unknown values', () {
      expect(MediaRole.tryParse('host'), MediaRole.host);
      expect(MediaRole.tryParse(' VIEWER '), MediaRole.viewer);
      expect(MediaRole.tryParse('audience'), isNull);
      expect(MediaRole.tryParse(null), isNull);
    });
  });

  group('BroadcastViewerSession', () {
    test('supports subscribe-only media plus chat', () async {
      final session = _ViewerOnlySession();
      await session.join(
        MediaJoinInfo(
          providerId: 'fake',
          roomCode: '482913',
          participantId: 'viewer-1',
          role: MediaRole.viewer,
        ),
      );

      expect(session.state, MediaSessionState.connected);
      expect(session.capabilities.canSubscribeVideo, isTrue);
      expect(session.capabilities.canPublishAudio, isFalse);
      expect(session.capabilities.canPublishVideo, isFalse);
      expect(session.capabilities.canSwitchCamera, isFalse);

      await session.sendMessage('hello host', topic: 'chat');
      expect(session.sentMessages, ['chat:hello host']);

      await session.leave();
      await session.dispose();
      expect(session.state, MediaSessionState.disposed);
    });

    test('viewer capabilities can disable data messages', () {
      const capabilities = MediaCapabilities.broadcastViewer(
        canSendData: false,
      );
      expect(capabilities.canSendData, isFalse);
      expect(capabilities.canSubscribeVideo, isTrue);
    });
  });

  group('MediaCapabilities presets', () {
    test('meeting preset publishes and subscribes', () {
      const capabilities = MediaCapabilities.meeting();
      expect(capabilities.canPublishAudio, isTrue);
      expect(capabilities.canPublishVideo, isTrue);
      expect(capabilities.canSubscribeVideo, isTrue);
      expect(capabilities.canScreenShare, isFalse);
    });

    test('host preset adds screen share', () {
      const capabilities = MediaCapabilities.broadcastHost();
      expect(capabilities.canScreenShare, isTrue);
      expect(capabilities.canPublishVideo, isTrue);
    });

    test('none preset declares nothing', () {
      const capabilities = MediaCapabilities.none();
      expect(capabilities.canPublishAudio, isFalse);
      expect(capabilities.canSubscribeVideo, isFalse);
    });
  });

  group('fake adapter role gating', () {
    test('viewer-role session cannot switch camera', () async {
      final factory = FakeMediaSessionFactory();
      final session = factory.createSession(
        MediaJoinInfo(
          providerId: 'fake',
          roomCode: '482913',
          participantId: 'viewer-1',
          role: MediaRole.viewer,
        ),
      );
      await session.join(
        MediaJoinInfo(
          providerId: 'fake',
          roomCode: '482913',
          participantId: 'viewer-1',
          role: MediaRole.viewer,
        ),
      );

      expect(
        () => session.switchCamera(MediaCameraPosition.back),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.unsupportedFeature,
          ),
        ),
      );
    });
  });
}
