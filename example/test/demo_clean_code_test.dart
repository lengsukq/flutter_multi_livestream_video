import 'dart:async';

import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:multi_video/demo_backend_diagnostics.dart';
import 'package:multi_video/demo_identity_store.dart';
import 'package:multi_video/demo_room_directory.dart';
import 'package:multi_video/demo_room_flow.dart';

void main() {
  test(
    'backend diagnostics ignores stale responses after URL change',
    () async {
      final state = DemoBackendDiagnostics();
      var url = 'http://first';
      final pending = Completer<MediaDoctorReport>();
      final inFlight = state.refresh(
        url: url,
        currentUrl: () => url,
        diagnose: () => pending.future,
      );
      expect(state.testing, true);
      url = 'http://second';
      pending.complete(
        const MediaDoctorReport(
          [
            MediaDoctorCheck(
              id: 'backend',
              status: MediaDoctorStatus.pass,
              message: 'ok',
            ),
          ],
          activeProvider: 'livekit',
          backendReachable: true,
        ),
      );
      await inFlight;
      expect(state.mediaProviderId, isNull);
      expect(state.testing, false);
      await state.refresh(
        url: url,
        currentUrl: () => url,
        diagnose: () async => const MediaDoctorReport(
          [
            MediaDoctorCheck(
              id: 'backend',
              status: MediaDoctorStatus.pass,
              message: 'ok',
            ),
          ],
          activeProvider: 'livekit',
          activeChatProvider: 'agora',
          backendReachable: true,
        ),
      );
      expect(state.online, true);
      expect(state.mediaProviderId, 'livekit');
      expect(state.chatProviderId, 'agora');
      state.clear();
      expect(state.online, isNull);
      state.dispose();
    },
  );

  test(
    'room discovery ignores stale backend responses and coalesces calls',
    () async {
      final directory = DemoRoomDirectory();
      var url = 'http://backend';
      var calls = 0;
      final pending = Completer<List<MediaRoomSummary>>();
      final first = directory.refresh(
        url: url,
        currentUrl: () => url,
        listRooms: () {
          calls++;
          return pending.future;
        },
        displayError: (e) => e.toString(),
      );
      final duplicated = directory.refresh(
        url: url,
        currentUrl: () => url,
        listRooms: () {
          calls++;
          return Future<List<MediaRoomSummary>>.value(
            const <MediaRoomSummary>[],
          );
        },
        displayError: (e) => e.toString(),
      );
      await duplicated;
      expect(calls, 1);
      url = 'http://new-backend';
      pending.complete([
        const MediaRoomSummary(
          roomCode: 'old',
          providerId: 'fake',
          attendeeCount: 1,
        ),
      ]);
      await first;
      expect(directory.rooms, isEmpty);
      await directory.refresh(
        url: url,
        currentUrl: () => url,
        listRooms: () async => [
          const MediaRoomSummary(
            roomCode: 'new',
            providerId: 'fake',
            attendeeCount: 2,
          ),
        ],
        displayError: (e) => e.toString(),
      );
      expect(directory.rooms.single.roomCode, 'new');
      directory.dispose();
    },
  );
  test(
    'Demo identity stays stable and persists display name independently of UI',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = DemoIdentityStore();
      final id = await store.loadDeviceId();
      expect(id, hasLength(36));
      expect(await store.loadDeviceId(), id);
      expect(await store.loadDisplayName(id), store.defaultDisplayName(id));
      await store.saveDisplayName('  Ada  ');
      expect(await store.loadDisplayName(id), 'Ada');
      await store.saveDisplayName(' ');
      expect(await store.loadDisplayName(id), 'Ada');
    },
  );

  test('Demo room intents use the public, provider-neutral SDK contract', () {
    final meeting = DemoRoomFlow.createRequest(
      mode: MediaRoomMode.meeting,
      deviceId: 'device-1',
      displayName: 'Ada',
      roomCode: '1234',
    );
    expect(meeting.action, RealtimeAction.create);
    expect(meeting.experience, RealtimeExperience.meeting);
    expect(meeting.roomCode, '1234');
    expect(meeting.user.id, 'device-1');

    final live = DemoRoomFlow.createRequest(
      mode: MediaRoomMode.broadcast,
      deviceId: 'device-2',
      displayName: 'Anchor',
      roomCode: '',
    );
    expect(live.experience, RealtimeExperience.live);
    expect(live.roomCode, isNull);

    final viewer = DemoRoomFlow.joinRequest(
      code: '2345',
      mode: MediaRoomMode.broadcast,
      deviceId: 'device-3',
      displayName: 'Viewer',
      ownerCredential: 'session-token',
    );
    expect(viewer.action, RealtimeAction.join);
    expect(viewer.experience, RealtimeExperience.live);
    expect(viewer.roomCode, '2345');
    expect(viewer.roomOwnerCredential, 'session-token');
  });
}
