# Local LiveKit E2E

This path verifies the provider-neutral Flutter API without deploying a cloud
backend. The LiveKit server and token-signing backend both run locally.

## Recommended: unified local backend

```bash
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
cd demo-server
npm start
```

Flutter then uses the provider-neutral backend at:

```text
http://127.0.0.1:3000
```

Both LiveKit and AWS Chime are available through the same `demo-server`
process. Open `http://127.0.0.1:3000/` and select LiveKit before this E2E. The
Flutter request itself never contains a provider.

The LiveKit dev credentials are local-only and are never returned to Flutter.

## Lower-level LiveKit-only commands

```bash
bash scripts/livekit-dev.sh install
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
```

For a physical device, `LIVEKIT_URL` must contain the Mac's LAN address, not
`127.0.0.1`. The helper exports the detected LAN address for `demo-server`.

## Optional Flutter integration test

The unified demo contains `integration_test/livekit_local_e2e_test.dart`:

```bash
flutter test integration_test/livekit_local_e2e_test.dart \
  --dart-define=MEDIA_E2E_BACKEND_URL=http://192.168.31.8:3000
```

Without `MEDIA_E2E_BACKEND_URL`, the platform project still builds and the test
then skips safely.

## Security boundary

- `LIVEKIT_API_SECRET` is read only by the Node backend.
- Flutter receives a short-lived participant JWT.
- Viewer JWTs set `canPublish: false` and `canSubscribe: true`.
- Participant identity is generated as an opaque UUID; the nickname is carried
  separately as the LiveKit display name.
- `DELETE /rooms/{code}` removes the application room directory entry. Local
  LiveKit itself automatically tears down empty rooms.

This script is a development reference, not a production authentication or
persistence service.
