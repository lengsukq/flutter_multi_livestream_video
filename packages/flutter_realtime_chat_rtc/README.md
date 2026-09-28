# flutter_realtime_chat_rtc

`flutter_realtime_chat_rtc` adapts an already-connected, fully bidirectional
RTC data transport into the provider-neutral `ChatSession` API.

Use it only when the room has no independent product Chat Provider. If
`room.chatProvider` is present, that product Chat session remains authoritative;
do not silently fall back after a product-chat connection failure.

```dart
final chat = room.chatProvider == null
    ? RtcDataChatSession.tryAttach(room: room)
    : null;
```

The adapter requires both `MediaCapabilities.canSendData` and
`canReceiveData`. It uses a dedicated versioned topic/envelope, maps incoming
RTC payloads to `ChatMessage`, deduplicates provider echo by message id, mirrors
media reconnect state, and releases all subscriptions on `dispose()`.

Messages are in-memory for the current session only. There is no server-side
history, delete-message moderation, or disconnect-user moderation. Raw RTC Data
Debug remains a separate `MediaDataMessenger` surface and is not part of the
Chat message stream.

Chat capability never changes microphone/camera publishing rights. A viewer may
chat only when its media role itself has bidirectional RTC data capability.
