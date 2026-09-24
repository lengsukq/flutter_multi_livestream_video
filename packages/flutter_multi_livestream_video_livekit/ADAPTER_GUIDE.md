# LiveKit adapter guide

`flutter_multi_livestream_video_livekit` implements provider-neutral
meeting/broadcast sessions on iOS and Android while keeping LiveKit SDK types
behind the adapter.

Supported roles are `participant`, `host`, and subscribe-only `viewer`.
`LiveKitViewerSession` is not an `InteractiveMediaSession`, and the backend must
also issue viewer tokens with `canPublish: false`.

Register the adapter with `LiveKitSessionFactory` and render Core video tracks
with `LiveKitTrackRenderer`.

Local development:

```bash
bash scripts/livekit-dev.sh start
eval "$(bash scripts/livekit-dev.sh env)"
cd demo-server
npm start
```

Then open `http://127.0.0.1:3000/` and select LiveKit. The same
`demo-server` URL is the Flutter backend URL.
