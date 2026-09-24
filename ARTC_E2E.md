# Alibaba Cloud ARTC device E2E

The unit tests run without Alibaba credentials. This optional device test checks
the SDK join/leave lifecycle, media controls, room roles, data channel, video
rendering, and credential renewal against a configured `demo-server` and real
Android/iOS devices.

## Configure the backend

Set `ARTC_APP_ID` and `ARTC_APP_KEY` on the server, select Alibaba Cloud ARTC in
the dashboard, then create a room as a `participant` or `host`. The server
keeps the AppKey and signs the short-lived join credentials. Keep the host's
room code for the viewer devices.

## Run a participant call

Run two devices with the same room code and `ARTC_E2E_ROLE=participant`; the
first device can create the room and the second joins the existing code. This
uses ARTC communication mode.

## Run a host with two viewers

Run one device as `host` with `ARTC_E2E_CREATE_ROOM=true`, then run two other
devices as `viewer` with `ARTC_E2E_CREATE_ROOM=false` and the host's room code.
On each viewer, set `ARTC_E2E_EXPECT_REMOTE_PARTICIPANTS=1` to confirm the host
is visible; optionally set `ARTC_E2E_RENDER_REMOTE_VIDEO=true` to attach the
native renderer. Keep both viewers connected during the run to confirm that
multiple viewers can watch the same host. The test does not require the host to
receive viewer participant events.

Each viewer session has a subscribe-only Core API and joins the native SDK as a
viewer. ARTC's signed auth token does not encode an enforced publish grant, so
this client role is not a security boundary against modified clients.

## Run the integration test

From `example/`, add the values as Dart defines to `flutter test` on a connected
Android or iOS device. For example:

```bash
flutter test integration_test/artc_device_e2e_test.dart \
  -d <device-id> \
  --dart-define=ARTC_E2E_BACKEND_URL=http://<server-lan-ip>:3000 \
  --dart-define=ARTC_E2E_ROLE=host \
  --dart-define=ARTC_E2E_CREATE_ROOM=true \
  --dart-define=ARTC_E2E_DEVICE_MEDIA=true \
  --dart-define=ARTC_E2E_HOLD_SECONDS=120
```

For viewers, pass `ARTC_E2E_ROLE=viewer`, `ARTC_E2E_CREATE_ROOM=false`, and the
room code. `ARTC_E2E_EXPECT_REMOTE_MESSAGE=true` checks a host message on a
viewer. The data channel requires an active publisher audio or video stream.

The 7.11.0 iOS CocoaPod contains a device framework and cannot link an iOS
Simulator build. Use a physical iPhone/iPad for this test.
