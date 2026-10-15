# Flutter Realtime Chat UI

Optional, provider-neutral Flutter components for **both** standalone chat and
media-attached chat. The package depends on `flutter_realtime_chat_core` and
Flutter, without importing RTC provider packages or media UI.

```dart
ChatUiScope(
  session: chatSession,
  moderation: chatModeration, // Optional SDK capability-gated governance
  child: Scaffold(
    body: Column(
      children: const [
        ChatSearchField(),
        Expanded(child: ChatMessageList()),
        ChatComposer(),
      ],
    ),
  ),
);
```

`ChatUiController` owns one subscription to chat connection state and one to
message snapshots, search text, reply target and operation state. Widgets can
be positioned independently inside a `Row`, `Column`, `Stack`, separate
drawer or modal. It does **not** own `ChatSession`: removing the UI does not
log the user out.

Public pieces include `ChatConnectionIndicator`, `ChatSearchField`,
`ChatMessageList`, `ChatComposer`, `ChatPanel`, `ChatManagementButton`,
`ChatMemberList` and `ChatRoomCodeCopy`. The complete standard page is
`RealtimeChatPage` in the optional `flutter_realtime_sdk_ui` package; this
component package contains no competing full-page template.

Host member actions are gated by `ChatManagementCapabilities`. Transport,
client vs backend execution, tokens, member authority and identity enforcement
remain the responsibility of the SDK/provider/backend, not presentation
widgets. In particular, combining provider and backend message deletion
requires `ChatMessageDeleteAction` to avoid duplicate operations.
