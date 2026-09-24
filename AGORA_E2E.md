# Agora real-service E2E

Agora verification is opt-in. The normal test suite does not require an Agora
account and does not consume real-service quota.

## Prerequisites

Create an Agora project and keep both values on the backend only:

- `AGORA_APP_ID`
- `AGORA_APP_CERTIFICATE`

If production security depends on a modified viewer client being unable to
publish, enable Agora's project-side co-host authentication capability and
verify that policy with this E2E. The reference backend already issues viewer
AccessToken2 credentials with audio/video/data publish privileges set to zero,
but project-side enforcement is an Agora account configuration boundary.

Start the existing single demo backend:

```bash
cd demo-server
AGORA_APP_ID=... AGORA_APP_CERTIFICATE=... npm start
```

Then open `http://127.0.0.1:3000/` and select **Agora RTC** for newly-created
rooms. Flutter never sends a provider selector.

For a physical phone, use the Mac/server LAN address instead of
`127.0.0.1`.

## Single-device lifecycle

This checks join/leave, microphone, camera and camera switching:

```bash
cd example
flutter test integration_test/agora_device_e2e_test.dart -d <device-id> \
  --dart-define=AGORA_E2E_BACKEND_URL=http://192.168.31.8:3000 \
  --dart-define=AGORA_E2E_ROLE=host \
  --dart-define=AGORA_E2E_DEVICE_MEDIA=true
```

Without `AGORA_E2E_BACKEND_URL`, the integration test skips safely.

## Two-device host + viewer

Use a fixed room code so both devices join the same room. Start the host first:

```bash
flutter test integration_test/agora_device_e2e_test.dart -d <host-device> \
  --dart-define=AGORA_E2E_BACKEND_URL=http://192.168.31.8:3000 \
  --dart-define=AGORA_E2E_ROOM_CODE=482913 \
  --dart-define=AGORA_E2E_ROLE=host \
  --dart-define=AGORA_E2E_DEVICE_MEDIA=true \
  --dart-define=AGORA_E2E_EXPECT_REMOTE_PARTICIPANT=true \
  --dart-define=AGORA_E2E_HOLD_SECONDS=30
```

Then start the viewer:

```bash
flutter test integration_test/agora_device_e2e_test.dart -d <viewer-device> \
  --dart-define=AGORA_E2E_BACKEND_URL=http://192.168.31.8:3000 \
  --dart-define=AGORA_E2E_ROOM_CODE=482913 \
  --dart-define=AGORA_E2E_ROLE=viewer \
  --dart-define=AGORA_E2E_CREATE_ROOM=false \
  --dart-define=AGORA_E2E_EXPECT_REMOTE_PARTICIPANT=true \
  --dart-define=AGORA_E2E_EXPECT_REMOTE_MESSAGE=true
```

The host waits for the viewer before sending the `e2e` RTC data message, so
the viewer can assert receipt. The viewer adapter never exposes interactive
media publishing methods.

## Two interactive participants

For bidirectional RTC data verification, run both devices as
`participant` with the same room code, set
`AGORA_E2E_EXPECT_REMOTE_PARTICIPANT=true` and
`AGORA_E2E_EXPECT_REMOTE_MESSAGE=true` on both, and set
`AGORA_E2E_CREATE_ROOM=false` only on the second device.

No Agora App Certificate or other long-lived secret is passed through
`--dart-define`.
