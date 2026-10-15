# Live interaction SDK (no payments)

## SDK boundary

`flutter_realtime_live_core` contains immutable gift/catalog/state types,
`LiveInteractionRepository`, `LiveRevisionTransport`, and `LiveInteractionSession`.
`flutter_realtime_live_preset` is an **optional**, UI-free business adapter
registering the existing Live session with `RealtimeFeatureRegistry`.
`flutter_realtime_live_ui` provides `LiveGiftPanel` and `LiveGiftOverlay`.
Neither package imports a media or Chat vendor SDK.

The host must explicitly register `LivePreset()` in `featurePlugins`, and
the provisioned room must advertise `liveInteractions: true`. The reference server advertises this for
Broadcast rooms. `RealtimeRoomView` renders the gift entry and incoming-event
animation on both hosts and viewers. The Live page's gift button uses `RealtimeLiveGiftButton` to open the shared
gift panel. `showLiveInteractions: false` suppresses this optional UI.
Session lifecycle and errors remain accessible to custom UI.
Applications can inject `LivePreset(repositoryFactory: ...)` for their own
trusted store; direct credentials do not silently create a reference backend.
For custom direct rooms without backend metadata, opt in via
`enableForDirectRooms: true` together with `repositoryFactory`.

```dart
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';

final realtime = Realtime(
  providers: myProviders,
  backendUrl: backendUrl,
  featurePlugins: const [LivePreset()],
);
final connection = await realtime.open(request);
final room = connection.mediaRoom!;
final gifts = room.liveInteractions;
if (gifts != null) {
  await gifts.start();
  final catalog = gifts.state!.catalog;
  final eventId = gifts.newEventId();
  await gifts.sendGift(catalog.first.id, quantity: 5, eventId: eventId);
  // If the request times out, retry with the SAME gift/quantity/eventId.
  // Listen to gifts.states, gifts.events and gifts.errors; cancel on disposal.
}
```

These are demonstration gifts. There is no currency, wallet, payment provider,
recharge, debit, withdrawal, or settlement API. The reference catalog uses local
Flutter icons for applause, flowers and stars. A custom repository can supply
its own catalog.

## Reference protocol

- `POST /rooms/:code/live/snapshot`
- `POST /rooms/:code/live/gift`

Both carry `requesterParticipantId` and `participantCredential`. Gift submission
additionally carries `giftId`, integer `quantity` (1–99), and `eventId`.
The joined identity is resolved by the server; sender/recipient identities
cannot be chosen in the submitted event. The recipient is the current host.
A missing host, wrong room mode, invalid credential or partially closed room
rejects the action. The reference limit is five gifts per sender per ten seconds.

Snapshots contain room/self/recipient identity, monotonic revision, catalog,
last 100 gift events and cumulative per-gift totals. Matching replay IDs are
idempotent while retained (last 1,000 submissions per room); conflicting payloads
return `idempotency-conflict`. Clients should retry promptly, not rely on
unbounded historical deduplication. State lasts for the current room lifecycle
only and is removed on clean close.

Product Chat system hints use `live.interaction.changed`; RTC hints use the
`live.interaction.v1` topic. Hints carry only a validated revision, never gift
state or authorization, and stay out of ordinary Chat messages. HTTP polling
(default two seconds) remains active when a vendor/role cannot send hints.
Hint and polling reads share one in-flight snapshot and are limited to at most
one automatic read per second, with at most one trailing read for a burst.
Explicit refreshes remain immediate. Ordinary Chat text resembling reserved
frames is escaped and restored; malformed reserved frames remain ordinary text.
Initial history does not replay animations. Newer authoritative events animate
once, including when the bounded event list stays the same length.

Media and product Chat selection are independent for all vendors, including
AWS Live. A room is bound to the selected Chat provider when created; dashboard
changes apply only to new rooms. No product Chat selection means no product
Chat. RTC chat fallback still requires bidirectional RTC data; this is distinct
from the polling-backed gift control plane.

## Platforms and evidence

The common Dart/Flutter implementation targets Web, Android, iOS and macOS.
This does not make every vendor/role Chat transport or screen-sharing method
available. Check the existing media and Chat capabilities.

Tests cover authenticated HTTP host/two-viewer state exchange against a local
mock media control plane, duplicate/conflicting submissions, rate limits,
no-host behavior, quiet initial history, revision isolation and a phone-sized
retry UI. This is not real vendor messaging or remote media acceptance.
See [interaction acceptance](INTERACTION_ACCEPTANCE.md) for remaining checks.
