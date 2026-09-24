## 0.1.0

* Initial provider-neutral core: session interfaces (`MediaSession`,
  `InteractiveMediaSession`, `BroadcastHostSession`, `BroadcastViewerSession`),
  shared models (state, snapshot, participant, track, message, capabilities,
  role, audio device), typed media and backend errors, and the event hierarchy.
* Add `MediaBackendClient` / `MediaClient` / `MediaRoomSession` implementing the
  provider-neutral backend contract with heartbeat and best-effort leave.
* Add `MediaRegistry` / `MediaSessionFactory` so provider SDKs stay optional.
* Add renderer injection (`MediaTrackRenderer`, `MediaTrackView`) so shared UI
  never imports a provider SDK.
