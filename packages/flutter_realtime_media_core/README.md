# flutter_realtime_media_core

Provider-neutral Flutter SDK core for realtime audio/video sessions and
one-to-many live broadcasts.

This package contains **no provider SDK dependency**. It defines the session,
event, error, capability, and rendering interfaces, plus a backend HTTP client
for the language-neutral [`MEDIA_BACKEND_CONTRACT.md`](../../MEDIA_BACKEND_CONTRACT.md).
Provider support is added by adapter packages that register a
`MediaSessionFactory`:

| Provider | Adapter package | Status |
| --- | --- | --- |
| LiveKit | `flutter_realtime_media_livekit` | Implemented |
| AWS Chime | `flutter_realtime_media_chime` (wrapping `flutter_aws_chime`) | Implemented |

## Why a separate core

An app that only uses one provider must not be forced to resolve the SDKs of
every other provider. The core stays SDK-free, and each adapter is an optional
dependency the app opts into.

## Roles

| Role | Interface | Can publish media |
| --- | --- | --- |
| Meeting participant | `InteractiveMediaSession` | yes |
| Broadcast host | `BroadcastHostSession` | yes |
| Broadcast viewer | `BroadcastViewerSession` | **no publish methods at all** |

`BroadcastViewerSession` deliberately has no mute/camera/publish member: the
type system is the client-side half of the broadcast guarantee. The other half
is the backend, which must issue viewer credentials without publish permission.

## Usage

```dart
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

final registry = MediaRegistry([LiveKitSessionFactory()]); // adapter package
final client = MediaClient(backendUrl: 'http://192.168.31.8:3000', registry: registry);

final room = await client.createRoomAndJoin(
  role: MediaRole.host,
  nickname: 'Host A',
);

await room.session.events.listen(print);
await (room.session as InteractiveMediaSession).setMuted(false);

await room.dispose();
client.dispose();
```

Failures are typed:

```dart
try {
  await client.joinRoom(roomCode: '482913', nickname: 'Leo');
} on MediaError catch (error) {          // media/session layer
  debugPrint('${error.code}: ${error.message}');
} on MediaBackendError catch (error) {   // backend HTTP layer
  debugPrint('${error.code}: ${error.message}');
}
```

## Contents

- `MediaSession`, `InteractiveMediaSession`, `BroadcastHostSession`,
  `BroadcastViewerSession`
- `MediaSessionState`, `MediaSnapshot`, `MediaParticipant`, `MediaVideoTrack`,
  `MediaMessage`, `MediaCapabilities`, `MediaRole`, `MediaAudioDevice`
- `MediaEvent` hierarchy (connection, participants, tracks, local media,
  messages, failures)
- `MediaError` / `MediaErrorCode` and `MediaBackendError` /
  `MediaBackendErrorCode`
- `MediaClient`, `MediaRoomSession`, `MediaBackendClient`,
  `MediaBackendTransport`
- `MediaRegistry`, `MediaSessionFactory`, `MediaJoinInfo`
- `MediaTrackRenderer`, `MediaTrackView`

## Testing

```bash
flutter test
```

Tests use fake adapters and a fake transport, so they run without a device,
network, or provider credentials.
