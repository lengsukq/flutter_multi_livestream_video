import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:multi_video/demo_identity_store.dart';
import 'package:multi_video/demo_join_coordinator.dart';
import 'package:multi_video/demo_room_flow.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

void main() {
  test(
    'avatar settings survive reopening and clearing restores name avatars',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = DemoIdentityStore();
      await store.saveAvatarUrl(' https://avatar.test/a.png ');
      expect(
        await DemoIdentityStore().loadAvatarUrl(),
        'https://avatar.test/a.png',
      );
      await store.saveAvatarUrl('file:///private/a.png');
      expect(await store.loadAvatarUrl(), 'https://avatar.test/a.png');
      await store.saveAvatarUrl('');
      expect(await store.loadAvatarUrl(), '');
    },
  );
  test(
    'meeting create and join preserve the profile prepared before Prejoin',
    () async {
      SharedPreferences.setMockInitialValues({
        DemoIdentityStore.deviceIdKey: 'device-avatar-user',
      });
      final coordinator = DemoJoinCoordinator(DemoIdentityStore());
      for (final kind in DemoRoomEntryKind.values) {
        final prepared = await coordinator.prepare(
          kind: kind,
          backendUrl: 'http://localhost',
          code: 'room123',
          displayName: '小明',
          avatarUrl: 'https://avatar.test/a.png',
          mode: MediaRoomMode.meeting,
          createRealtime: (_) =>
              Realtime.fromSdk(RealtimeSdk(plugins: const [])),
        );
        final user = (prepared as DemoJoinPrepared).entry.user;
        final request = kind == DemoRoomEntryKind.create
            ? DemoRoomFlow.createRequest(
                mode: MediaRoomMode.meeting,
                deviceId: user.id,
                displayName: user.name,
                avatarUrl: user.avatarUrl,
              )
            : DemoRoomFlow.joinRequest(
                code: 'room123',
                mode: MediaRoomMode.meeting,
                deviceId: user.id,
                displayName: user.name,
                avatarUrl: user.avatarUrl,
              );
        expect(request.user.avatarUrl, 'https://avatar.test/a.png');
      }
    },
  );
}
