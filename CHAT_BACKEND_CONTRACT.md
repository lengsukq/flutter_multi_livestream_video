# Chat Backend Contract v1

Product chat is independent from the media provider. A room can use any
supported media provider and optionally bind a separate chat provider. RTC data
messages are not a substitute for this contract when `chatProvider` is bound.
When no product Chat Provider is bound, a client may optionally adapt a fully
bidirectional RTC data transport into a session-local `ChatSession` fallback;
that path does not call this backend contract and does not provide server-side
history or moderation.

## Versioning

Chat requests send header X-Realtime-Chat-Contract: 1. Authentication uses the
same application-level Authorization or custom headers as the media backend.
Provider API credentials remain server-side.

## Issue chat credentials

POST /rooms/{roomCode}/chat/token

Request:

~~~json
{
  "participantId": "viewer-a",
  "participantCredential": "<opaque-session-proof>"
}
~~~

participantId must already belong to the media room and participantCredential
must be the opaque proof issued to that exact participant by the media join
response. Knowing another participant's id is therefore insufficient to mint
their chat token. The client does not send userId, displayName, or role to
obtain chat permission. The backend validates the participant proof, resolves
the stored media participant, and grants capabilities from that server-side
identity/role.

The media backend must also establish that role without trusting public,
client-declared identity fields. In particular, `userId`, `displayName`,
and `deviceId` must not restore a broadcast `host`. The reference backend
issues a separate random `roomOwnerCredential` when the broadcast is created
and only a join presenting that proof can become `host`. This matters because
chat messages may expose the sender's logical `userId`; learning that value
must not allow another participant to obtain `DELETE_MESSAGE` or
`DISCONNECT_USER`.

Response:

~~~json
{
  "contractVersion": 1,
  "chatProvider": "ivs-chat",
  "roomCode": "482913",
  "participantId": "viewer-a",
  "userId": "account-123",
  "displayName": "Viewer A",
  "role": "viewer",
  "chat": {
    "roomArn": "arn:aws:ivschat:us-west-2:123456789012:room/abc",
    "token": "<short-lived-chat-token>",
    "capabilities": ["SEND_MESSAGE"],
    "tokenExpirationTimeMs": 1790570600000,
    "sessionExpirationTimeMs": 1790573600000,
    "region": "us-west-2"
  }
}
~~~

The `chat` object is provider-specific. Current reference adapters use these
shapes in addition to Amazon IVS Chat:

~~~json
{
  "chatProvider": "tencent-chat",
  "chat": {
    "sdkAppId": 1400000001,
    "groupId": "rm_482913",
    "providerUserId": "u_ab12...",
    "userSig": "<short-lived-usersig>",
    "capabilities": ["SEND_MESSAGE"],
    "userSigExpirationTimeMs": 1790570600000
  }
}
~~~

~~~json
{
  "chatProvider": "agora-chat",
  "chat": {
    "appKey": "org#app",
    "chatRoomId": "123456789",
    "providerUserId": "u_cd34...",
    "token": "<short-lived-chat-user-token>",
    "capabilities": ["SEND_MESSAGE"],
    "tokenExpirationTimeMs": 1790570600000
  }
}
~~~

For Amazon IVS Chat, participant/viewer receives SEND_MESSAGE. Host receives
SEND_MESSAGE, DELETE_MESSAGE, and DISCONNECT_USER. Token duration is clamped to
the AWS-supported 1-180 minute range. During reconnect, the native Chat SDK
requests a fresh token through Dart instead of reusing a consumed token.

Tencent Cloud Chat and Agora Chat currently receive SEND_MESSAGE only. Their
managed services provide broader moderation APIs, but the current Flutter
`ChatSession` adapter intentionally does not grant client-side delete/kick
authority. Tencent reconnect refreshes UserSig and Agora reconnect renews the
Chat user token through the same credential callback. Provider secrets and
REST app/admin tokens never leave the backend.

The participantCredential is not an AWS credential. The reference backend
generates 32 random bytes per admitted participant, returns the opaque value
only to that participant, and stores only a SHA-256 digest. A new join for that
participant rotates the proof.

If a room has no chat provider, the reference backend returns
unsupported-feature. Clients may then decide whether their current media
session supports the optional RTC Chat fallback. Unknown rooms or participants
return typed errors. A failure while connecting a configured product Chat must
not be interpreted as permission to silently switch to fallback.

## Room lifecycle

The backend creates the product-chat room together with the media room when a
Chat Provider is enabled and deletes both when the application room closes.
Changing the default Media or Chat Provider affects only newly created rooms;
existing rooms retain both bindings.
