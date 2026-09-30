@TestOn('browser')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_web/flutter_realtime_media_web.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Agora Web advertises SDK background blur for publishers', () {
    if (!kIsWeb) return;
    final factory = ProviderWebSessionFactory('agora');

    expect(
      factory.backgroundCapabilitiesFor(MediaRole.participant).canBlur,
      isTrue,
    );
    expect(factory.backgroundCapabilitiesFor(MediaRole.host).canBlur, isTrue);
    expect(
      factory.backgroundCapabilitiesFor(MediaRole.viewer).canBlur,
      isFalse,
    );
  });

  test('Web providers expose background effects to publishers only', () {
    if (!kIsWeb) return;
    for (final providerId in ['agora', 'trtc', 'artc', 'ivs', 'chime']) {
      final factory = ProviderWebSessionFactory(providerId);
      final publisher = factory.backgroundCapabilitiesFor(
        MediaRole.participant,
      );
      expect(publisher.canBlur, isTrue, reason: providerId);
      expect(publisher.canReplaceImage, isTrue, reason: providerId);
      expect(
        factory.backgroundCapabilitiesFor(MediaRole.viewer).isSupported,
        isFalse,
        reason: providerId,
      );
    }
  });

  test('Agora Web publisher session exposes background controller', () {
    if (!kIsWeb) return;
    final factory = ProviderWebSessionFactory('agora');
    final joinInfo = factory.parseJoinInfo({
      'provider': 'agora',
      'roomCode': 'room-a',
      'participantId': '42',
      'displayName': 'Ada',
      'role': 'participant',
      'agora': {
        'appId': 'app-id',
        'channelName': 'room-a',
        'token': 'token',
        'uid': 42,
      },
    });
    final session = factory.createSession(joinInfo);

    expect(session, isA<MediaBackgroundEffectsController>());
    expect(session, isA<ProcessedVideoSink>());
    expect(session.capabilities.canBlurBackground, isTrue);
  });

  test('Agora Web exposes independent SDK local preview', () {
    if (!kIsWeb) return;
    final factory = ProviderWebSessionFactory('agora');

    expect(factory, isA<MediaLocalPreviewFactory>());
    expect(factory, isA<MediaBackgroundCapabilitiesProvider>());
  });
}
