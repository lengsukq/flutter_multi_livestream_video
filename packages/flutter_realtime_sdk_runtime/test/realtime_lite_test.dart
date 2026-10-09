import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

Future<void> assets({
  Iterable<String> mediaProviderIds = const [],
  bool includeProductChat = false,
  bool includeAllMediaProviders = false,
}) async {}
void main() {
  test('lite requires explicit providers', () {
    expect(() => Realtime(providers: const []), throwsArgumentError);
  });
  test(
    'composition registers only selected providers and retains shared types',
    () {
      final bundle = RealtimeProviderBundle(
        drivers: [
          RealtimeProviderDriver(
            platforms: const {RealtimeRuntimePlatform.macos},
            publicProviderId: 'aws',
            mediaRoomModes: const {MediaRoomMode.meeting},
            plugin: const RealtimeProviderPlugin(
              id: 'chime',
              metadata: RealtimeProviderMetadata(displayName: 'AWS'),
              mediaFactory: _Factory(),
              renderer: _Renderer(),
            ),
          ),
        ],
        webAssetsLoader: assets,
      );
      final realtime = Realtime(
        providers: [bundle],
        platformResolver: () => RealtimeRuntimePlatform.macos,
      );
      expect(realtime.supportedProviderIds, ['aws']);
      expect(realtime.supportsProvider('agora'), isFalse);
      expect(
        realtime.sdk.driverRegistry!.resolveMediaEngine(
          providerId: 'aws',
          roomMode: MediaRoomMode.meeting,
        ),
        'chime',
      );
    },
  );
}

class _Factory implements MediaSessionFactory {
  const _Factory();
  @override
  String get providerId => 'chime';
  @override
  Set<MediaRole> get supportedRoles => const {MediaRole.participant};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Renderer extends MediaTrackRenderer {
  const _Renderer();
  @override
  Widget buildView(BuildContext context, MediaVideoTrack track) =>
      const SizedBox();
}
