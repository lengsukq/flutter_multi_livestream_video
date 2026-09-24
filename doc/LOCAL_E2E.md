# Local multi-provider testing

## Backend modes

```bash
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
cd demo-server
npm start
```

Open `http://127.0.0.1:3000/` to select the provider used for newly created
rooms. `/health` reports the active provider and configuration status.

## Flutter demo

```bash
cd example
flutter run \
  --dart-define=MEDIA_BACKEND_URL=http://<host>:3000
```

Add `--dart-define=MEDIA_APP_TOKEN=<token>` only if your application backend
requires an app-level bearer token.

Provider selection is backend-only. Existing rooms resolve by room code and
keep their original provider after the admin switch changes. Chime currently
guarantees participant only; selecting Chime and requesting host/viewer returns
an explicit backend error.

## Optional LiveKit integration test

`example/integration_test/livekit_local_e2e_test.dart`
contains a two-client test. Run it on an iOS/Android simulator or device with:

```bash
flutter test integration_test/livekit_local_e2e_test.dart \
  --dart-define=MEDIA_E2E_BACKEND_URL=http://<host>:3000
```

Without `MEDIA_E2E_BACKEND_URL`, the test skips safely. Real microphone/camera
behavior depends on simulator/device capabilities; the repository's automated
unit/contract suites do not require a real cloud deployment.

## Optional Tencent TRTC integration test

See [`../TRTC_E2E.md`](../TRTC_E2E.md) for the backend setup, one-device media
and rendering test, host plus two-viewer checks, server-enforced viewer
permissions, and short-lived credential renewal test. These checks require a
Tencent RTC project and physical Android/iOS devices; the offline suites use a
fake TRTC engine.
