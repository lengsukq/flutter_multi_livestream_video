# Unified real-call acceptance

The new `example/integration_test/realtime_acceptance_test.dart` is opt-in.
Ordinary CI does not join providers. Defaults: 20 complete join/leave cycles followed by a separate endurance join and a 30-minute final session.
Use existing configured test projects and physical devices; no credentials are
discovered or downloaded by this test.

## Running a configured room

Provision a test room and keep the remote peer(s) connected throughout the run.
Run from `example/`:

```sh
flutter test integration_test/realtime_acceptance_test.dart -d <device-id> \
  --dart-define=ACCEPTANCE_BACKEND_URL=http://<test-backend>:3000 \
  --dart-define=ACCEPTANCE_ROOM_CODE=<room-code> \
  --dart-define=ACCEPTANCE_PROVIDER=livekit \
  --dart-define=ACCEPTANCE_DEVICE=<device-model-and-os> \
  --dart-define=ACCEPTANCE_VENDOR_SDK_VERSION=<locked-vendor-version>
```

For live, add `ACCEPTANCE_LIVE=true`; the publisher must observe two viewers
(`ACCEPTANCE_REMOTE_COUNT=2`). A viewer adds `ACCEPTANCE_VIEWER=true`.
Repeat publisher tests with `ACCEPTANCE_EFFECT=blur` and `replaceImage`.
Camera switching is explicit via `ACCEPTANCE_SWITCH_CAMERA=true` and requires
front/back cameras. Providers without the requested capability must report
unsupported; do not mark that scenario passed.

During the endurance session, manually interrupt and restore the network; add
`ACCEPTANCE_EXPECT_RECOVERY=true` to require a recovered event. Token renewal
must additionally run the existing provider-specific short-TTL tests documented
in TRTC_E2E.md, ARTC_E2E.md, AGORA_E2E.md and DEVICE_E2E.md. The generic endurance
test does not claim to prove renewal just because a session remains connected.

`ACCEPTANCE_CYCLES` and `ACCEPTANCE_HOLD_SECONDS` can shorten debugging runs;
only record the default 20/1800 run as full lifecycle/endurance acceptance.

## Remote visual review

Remote observers record screenshots/video evidence for blur and image replacement:
portrait/landscape, front/back camera, geometry/aspect ratio, cheek/temple edges,
none/effect transitions and restoration after reconnect. A remote participant or
published-track event proves presence, not correct pixels. The automated record
always leaves `remoteFrameReview` pending until a human attaches this evidence.

## Result and cleanup

Copy the sanitized `ACCEPTANCE {...}` JSON lines into a local report using
`doc/acceptance-record.example.json`. Record platform, actual device/OS, provider,
engine and locked vendor version. Keep separate `implemented`, `build`, `realCall`
and `remoteVisual` fields. Missing credentials/devices and unsupported combinations
remain `pending` or `unsupported`, never `passed`.

The test releases its own connection in `finally`. Room owners must delete rooms
and verify deletion separately. `ACCEPTANCE_CLOSE_ROOM=true` is only for an
explicitly authorized owner connection and still requires control-plane proof.
AWS runs use `chime-demo`, Chime control plane `us-east-1`; delete each probe meeting
and confirm `get-meeting` returns `NotFoundException`. Local leave alone is not
provider resource cleanup.
