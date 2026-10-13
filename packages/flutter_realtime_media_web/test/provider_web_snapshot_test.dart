import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_web/src/provider_web_snapshot_decoder.dart';
import 'package:flutter_realtime_media_web/src/provider_web_join_info_decoder.dart';
import 'package:flutter_realtime_media_web/src/provider_web_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removing shared content emits track release and clears its owner', () {
    final first = decodeProviderWebSnapshot(
      providerId: 'agora',
      sessionId: 's',
      previous: MediaSnapshot(),
      previousTracks: const {},
      event: {
        'localParticipantId': 'self',
        'tracks': [
          {'id': 'share', 'participantId': 'teacher', 'isScreenShare': true},
        ],
        'participants': [
          {'id': 'teacher', 'videoTrackId': 'share'},
        ],
      },
    );
    expect(first.snapshot.contentShareTrack?.id, 'share');
    expect(first.events.whereType<MediaTrackPublished>(), hasLength(1));
    final next = decodeProviderWebSnapshot(
      providerId: 'agora',
      sessionId: 's',
      previous: first.snapshot,
      previousTracks: first.tracks,
      event: {'tracks': <Object?>[], 'participants': <Object?>[]},
    );
    expect(next.snapshot.contentShareTrack, isNull);
    expect(next.snapshot.localParticipantId, isNull);
    expect(next.events.whereType<MediaTrackUnpublished>(), hasLength(1));
    expect(next.events.whereType<MediaParticipantLeft>(), hasLength(1));
    expect(() => first.tracks.clear(), throwsUnsupportedError);
    expect(() => next.events.clear(), throwsUnsupportedError);
  });
  test(
    'join payload for a different provider fails before a session exists',
    () {
      final decoder = ProviderWebJoinInfoDecoder(
        'agora',
        ProviderWebProfile.forProvider('agora'),
      );
      expect(
        () => decoder.decode({'provider': 'trtc'}),
        throwsA(isA<RealtimeException>()),
      );
    },
  );
}
