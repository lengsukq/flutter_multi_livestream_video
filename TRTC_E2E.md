# Tencent TRTC device E2E

TRTC service checks are opt-in. Offline tests use a fake engine and do not need
a Tencent account, real credentials, or network access.

## Configure the reference backend

Create a Tencent RTC application and keep the signing secret on the backend.
Enable **Advanced Permission Control** so the room-scoped PrivateMapKey rights
issued by the server are enforced. Configure the ignored `demo-server/.env`
file or the server process with:

```text
TRTC_SDK_APP_ID=<Tencent SDKAppID>
TRTC_SDK_SECRET_KEY=<server-only secret>
TRTC_TOKEN_TTL_SECONDS=600
```

Start the demo backend and select **Tencent TRTC** in its dashboard for new
rooms. For a physical device, pass a backend URL reachable from that device,
such as the development machine's LAN address. Do not put the TRTC secret in
Flutter defines or app configuration.

## One-device host lifecycle and rendering

This checks TRTC join/leave, microphone, camera, camera switching, and local
video rendering:

```bash
cd example
flutter test integration_test/trtc_device_e2e_test.dart -d <device-id> \
  --dart-define=TRTC_E2E_BACKEND_URL=http://192.168.31.8:3000 \
  --dart-define=TRTC_E2E_ROLE=host \
  --dart-define=TRTC_E2E_DEVICE_MEDIA=true
```

Without `TRTC_E2E_BACKEND_URL`, the test skips. The test registers only
`TrtcSessionFactory`, which also demonstrates that the app can include TRTC
without registering any other adapter.

## Host and two viewers

Choose a room code. Start the host first; it enables its camera and waits until
both viewers join before sending a message:

```bash
flutter test integration_test/trtc_device_e2e_test.dart -d <host-device> \
  --dart-define=TRTC_E2E_BACKEND_URL=http://192.168.31.8:3000 \
  --dart-define=TRTC_E2E_ROOM_CODE=482913 \
  --dart-define=TRTC_E2E_ROLE=host \
  --dart-define=TRTC_E2E_DEVICE_MEDIA=true \
  --dart-define=TRTC_E2E_EXPECT_REMOTE_PARTICIPANTS=2 \
  --dart-define=TRTC_E2E_HOLD_SECONDS=60
```

Start each viewer on a separate device, using the same room code:

```bash
flutter test integration_test/trtc_device_e2e_test.dart -d <viewer-device-1> \
  --dart-define=TRTC_E2E_BACKEND_URL=http://192.168.31.8:3000 \
  --dart-define=TRTC_E2E_ROOM_CODE=482913 \
  --dart-define=TRTC_E2E_ROLE=viewer \
  --dart-define=TRTC_E2E_CREATE_ROOM=false \
  --dart-define=TRTC_E2E_EXPECT_REMOTE_PARTICIPANTS=1 \
  --dart-define=TRTC_E2E_EXPECT_REMOTE_MESSAGE=true \
  --dart-define=TRTC_E2E_RENDER_REMOTE_VIDEO=true
```

Repeat the viewer command with the second device. Each viewer asserts that its
session has no publish or message-send surface, receives the host's custom
message, and creates the remote video view. The service-side PrivateMapKey is
the enforcement boundary for clients that bypass the Flutter API.

## Credential renewal

Set `TRTC_TOKEN_TTL_SECONDS=60` on the backend and run a single device with:

```bash
flutter test integration_test/trtc_device_e2e_test.dart -d <device-id> \
  --dart-define=TRTC_E2E_BACKEND_URL=http://192.168.31.8:3000 \
  --dart-define=TRTC_E2E_ROLE=host \
  --dart-define=TRTC_E2E_EXPECT_RENEWAL=true \
  --dart-define=TRTC_E2E_RENEWAL_TIMEOUT_SECONDS=75
```

The test waits for the adapter's reconnecting transition and confirms it returns
to connected after refreshing the same participant's credentials. The reference
backend caps only the credential lifetime; it does not expose server secrets in
the join or refresh response.
