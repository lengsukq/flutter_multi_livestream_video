# Real-device Chime E2E

The repository includes an opt-in integration test at
`example/integration_test/chime_device_e2e_test.dart`. It connects to a real
application backend and exercises the native Amazon Chime SDK on Android or
iOS hardware.

The test is skipped unless `CHIME_E2E_BACKEND_URL` is supplied. No AWS access
key or secret key belongs in the Flutter app or in these test commands.

## Before running

1. Start or deploy a backend that implements `BACKEND_CONTRACT.md`. The bundled
   `demo-server` is sufficient for local testing.
2. Connect a physical Android or iOS device.
3. Ensure the device can reach the backend URL.
4. Grant microphone and camera permission when prompted. For repeatable CI-lab
   devices, pre-grant those permissions before starting the test.

## Create a room and run the lifecycle test

From `example/`:

```bash
flutter test integration_test/chime_device_e2e_test.dart \
  -d <device-id> \
  --dart-define=CHIME_E2E_BACKEND_URL=http://192.168.1.10:3000 \
  --dart-define=CHIME_E2E_NICKNAME=device-a
```

If the backend requires application authentication, add:

```bash
--dart-define=CHIME_E2E_TOKEN=<short-lived-app-token>
```

The positive-path test verifies:

- backend create/join and Chime media connection;
- microphone unmute/mute;
- audio-device enumeration and selection when devices are exposed;
- local video start/stop;
- front/back camera switching;
- data-message send path;
- leave and idempotent disposal.

Use `--dart-define=CHIME_E2E_SKIP_CAMERA_SWITCH=true` only for hardware that
does not have both front and back cameras.

## Two-device attendee check

Choose a fixed room code. Start the host and keep it connected long enough for
the guest to join:

```bash
flutter test integration_test/chime_device_e2e_test.dart \
  -d <host-device-id> \
  --dart-define=CHIME_E2E_BACKEND_URL=http://192.168.1.10:3000 \
  --dart-define=CHIME_E2E_ROOM_CODE=482913 \
  --dart-define=CHIME_E2E_CREATE_ROOM=true \
  --dart-define=CHIME_E2E_HOLD_SECONDS=60 \
  --dart-define=CHIME_E2E_EXPECT_REMOTE_ATTENDEE=true \
  --dart-define=CHIME_E2E_NICKNAME=host
```

Then run on the guest device:

```bash
flutter test integration_test/chime_device_e2e_test.dart \
  -d <guest-device-id> \
  --dart-define=CHIME_E2E_BACKEND_URL=http://192.168.1.10:3000 \
  --dart-define=CHIME_E2E_ROOM_CODE=482913 \
  --dart-define=CHIME_E2E_CREATE_ROOM=false \
  --dart-define=CHIME_E2E_NICKNAME=guest
```

## Failure-path checks

Some failure modes require OS or network control and are intentionally not
faked inside the package test:

- **Permission denied:** revoke microphone/camera permission in system settings,
  rerun the test, and verify a typed `permissionDenied` media error.
- **Invalid/expired app token:** run with an invalid `CHIME_E2E_TOKEN` and
  verify the backend returns a typed authentication/backend error.
- **Network interruption/reconnect:** while connected, disable network access,
  restore it, and verify reconnect state/events before continuing media calls.
- **Backend unavailable:** stop the backend before create/join and verify a
  typed network/backend error rather than an untyped crash.

These scenarios are suitable for a device lab where permissions and network
can be controlled externally. They are not run in the ordinary GitHub Actions
workflow because that workflow has no real Chime credentials or physical
devices.
