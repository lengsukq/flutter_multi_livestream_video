import 'package:flutter/widgets.dart';
import 'package:flutter_multi_livestream_video_core/flutter_multi_livestream_video_core.dart';
import 'package:flutter_multi_livestream_video_livekit/flutter_multi_livestream_video_livekit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveKit session contract', () {
    test('publisher exposes the declared media capabilities', () {
      final session = LiveKitInteractiveSession();

      expect(session.role, MediaRole.participant);
      expect(session.state, MediaSessionState.idle);
      expect(session.capabilities.canPublishAudio, isTrue);
      expect(session.capabilities.canPublishVideo, isTrue);
      expect(session.capabilities.canSwitchCamera, isTrue);
      expect(session.capabilities.canScreenShare, isTrue);
      expect(session.capabilities.canSubscribeVideo, isTrue);
    });

    test('viewer is subscribe-only at the Dart type and capability layers', () {
      final MediaSession session = LiveKitViewerSession();

      expect(session, isA<BroadcastViewerSession>());
      expect(session, isNot(isA<InteractiveMediaSession>()));
      expect(session.role, MediaRole.viewer);
      expect(session.capabilities.canPublishAudio, isFalse);
      expect(session.capabilities.canPublishVideo, isFalse);
      expect(session.capabilities.canScreenShare, isFalse);
      expect(session.capabilities.canSubscribeVideo, isTrue);
    });

    test('media operations fail with typed invalidState before join', () async {
      final session = LiveKitInteractiveSession();

      await expectLater(
        session.setMuted(false),
        throwsA(
          isA<MediaError>().having(
            (error) => error.code,
            'code',
            MediaErrorCode.invalidState,
          ),
        ),
      );
      await expectLater(
        session.setVideoEnabled(true),
        throwsA(isA<MediaError>()),
      );
      await expectLater(
        session.sendMessage('hello'),
        throwsA(isA<MediaError>()),
      );
      await session.dispose();
    });

    test('dispose is idempotent without a provider connection', () async {
      final session = LiveKitViewerSession();
      final states = <MediaSessionState>[];
      final subscription = session.states.listen(states.add);

      await session.dispose();
      await session.dispose();
      await pumpEventQueue();

      expect(session.state, MediaSessionState.disposed);
      expect(states, contains(MediaSessionState.disposed));
      await subscription.cancel();
    });

    testWidgets('renderer rejects a track from another provider', (
      tester,
    ) async {
      final renderer = LiveKitTrackRenderer();
      late Object thrown;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            try {
              renderer.buildView(context, const _OtherProviderTrack());
            } catch (error) {
              thrown = error;
            }
            return const SizedBox.shrink();
          },
        ),
      );

      expect(thrown, isA<ArgumentError>());
    });
  });
}

class _OtherProviderTrack extends MediaVideoTrack {
  const _OtherProviderTrack();

  @override
  String get id => 'other-track';

  @override
  String get participantId => 'other-participant';

  @override
  bool get isLocal => false;

  @override
  bool get isScreenShare => false;

  @override
  int get width => 0;

  @override
  int get height => 0;
}
