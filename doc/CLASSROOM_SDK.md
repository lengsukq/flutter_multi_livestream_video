# Classroom SDK V1 (Meeting)

## SDK-first boundary

The independent packages are:

- flutter_realtime_classroom_core: teacher/student roles, question state,
  raised hands, speaking grants, stats, notifications, state repository and
  optional revision transport.
- flutter_realtime_classroom_ui: teacher/student panels and an optional
  floating classroom entry point.
- flutter_realtime_sdk_runtime: attaches a ClassroomSession to RealtimeRoom for
  backend-provisioned Meeting rooms, choosing a product IM system-hint
  transport when available or RTC Data when not.

The example app has no classroom-specific API integration. It uses the generic
RealtimeRoomView, whose optional classroom entry appears when room.classroom
is available. The Demo is an SDK integration test, not a home for business logic.

## Usage

Create or join a Meeting using Realtime.standard and open(RealtimeRequest).
Then use the SDK's optional ClassroomSession:

~~~dart
final room = connection.mediaRoom!;
final classroom = room.classroom;
if (classroom != null) {
  await classroom.start();
  final subscription = classroom.states.listen((state) {
    print(state.stats.handsRaised);
    print(state.capabilities.canGrantSpeak);
  });
  final eventSubscription = classroom.events.listen((event) {
    // Typed hand, question, speaking-permission and presence transitions.
    print(event.kind);
  });
  // Students:
  await classroom.raiseHand();
  await classroom.askQuestion('Can you explain this?');
  if (classroom.state!.capabilities.canSendFeedback) {
    await classroom.sendFeedback(ClassroomFeedbackKind.question);
  }
  // Teachers (verified by backend room owner credential):
  // await classroom.grantSpeak(studentId);
  // await classroom.answerQuestion(questionId, 'Sure.');
  // await classroom.resolveQuestion(questionId);
  // Cancel both subscriptions on UI disposal.
}
~~~

Developers may supply their own ClassroomRepository and ClassroomRevisionTransport
to ClassroomSession if their backend does not use the reference HTTP contract.

## Reference control-plane protocol

For a backend Meeting room with a participant credential, SDK attaches:

- POST /rooms/:code/classroom/snapshot
- POST /rooms/:code/classroom/action

Every request includes requesterParticipantId + participantCredential. Teacher
privileges require a valid roomOwnerCredential. Action identifiers:
hand.raise, hand.lower, speak.grant, speak.revoke, question.ask,
question.answer, question.resolve, feedback.send. User or question ids and text are supplied
as appropriate. The response is the full ClassroomState, with increasing
revision, selfUserId, students (including offline users and logical roles),
questions, and stats. Unknown actions and
unauthorized mutations are rejected, rather than applied optimistically.
Mutating requests use per-action eventId keys. The reference backend limits
question bursts (three submissions per student per 30 seconds), rejects
reused eventIds with conflicting payloads, and bounds room question history.
Raise-hand queue ordering uses a persistent monotonically increasing sequence
instead of wall-clock milliseconds. Stats distinguish active hands and pending
questions from cumulative raises, all submitted questions and speaking grants.
The chatMessages field remains local to the connected ChatSession (not a
server-wide, historic class chat count).

Quick feedback uses `kind` (`understood`, `great`, `idea`, `question`, `clap`).
The server supplies sender identity, display name, ID and timestamp from the
authenticated participant. Teachers can read all recent feedback; student
snapshots contain only their own responses. The room retains its latest 200
responses and limits each student to five submissions per ten seconds.
Feedback is available by default without a UI toggle or setup action.
Missing `feedbackSupported` preserves that default, including older snapshot
shapes. Repositories can explicitly return `feedbackSupported: false` when
they cannot implement feedback; the UI then reports unsupported service rather
than implying that someone needs to enable a setting. An older server still
needs the `feedback.send` action implementation before it can accept responses.
The optional classroom UI confirms sending only after backend acceptance,
shows teachers a short-lived bubble and unread badge, and retains a Feedback
tab with sender, type, time and counts for the retained window. Notifications
are derived from trusted snapshots and do not replay history on initial join.
Existing revision hints refresh the receiver promptly; polling remains the
fallback when hints are unavailable. Update the reference backend alongside
the client to enable this contract. Optional classroom persistence also stores
feedback and its rate-limit state.

By default the reference backend keeps its classroom state in memory.
Set CLASSROOM_STATE_DIR to enable an optional single-host FileClassroomStore:
it writes atomic JSON snapshots under restrictive file permissions and
restores revisions, raised hands, Q&A, participant-bound grants, rate-limit state and event IDs
when the same room identity (provider + roomCode + createdAt) is reconstructed.
A grant is restored only when its saved participant binding matches the current
media participant. Legacy snapshots without that binding lose their grants.
The file is deleted when the room is cleanly closed. Room registry and provider
sessions are still ephemeral: this does **not** restore a closed/media room,
implement cross-process locks or make a multi-instance deployment production
ready. For HA deployments, implement ClassroomStore with a shared,
transactionally updated database/Redis design along with durable room identity
restoration; the Demo itself remains a reference server only.

## Realtime update strategy

Both product Chat and RTC Data carry **only versioned, room-scoped
revision notifications** (v, type, roomCode, revision, eventId, timestampMs).
Product IM sessions in Agora Chat, Tencent Chat and Amazon IVS Chat use an
optional ChatSystemMessaging contract. The adapters filter reserved system
frames from user-facing ChatSession.messages, messageSnapshots and events.
Normal user messages beginning with a reserved system/text prefix are escaped
and restored as user text. Only structurally valid versioned revision envelopes
are routed to system hints; malformed reserved text remains visible in Chat.
Automatic reads from hints and polling share one in-flight snapshot and a
one-second minimum interval. Bursts queue at most one trailing read; explicit
refreshes bypass the cooldown and action responses apply immediately.
The reserved frames are plain-text messages at the vendor transport level;
non-SDK clients should not render them as normal chat. If the selected
ChatSession cannot send system frames, RTC Data is selected instead.
Messages with the wrong room/version or expired timestamps are dropped.
They are untrusted invalidation hints, never teacher commands or state payloads.
On a higher revision, ClassroomSession reads the authoritative state from its
repository. A polling fallback (default 2 seconds) works when the current
provider cannot send IM/RTC Data or when notifications are missed. Product Chat
remains a separate ChatSession: SDK-facing user chat messages never contain
the classroom control envelope.

## V1 scope and limitations

- Raising/lowering a hand, teacher approving/revoking a speaking request,
  Q&A replies/resolution, roster, reminders and live statistics work via the
  SDK. All teacher mutations are authorized at the control plane.
- Speaking grant enforcement depends on the media provider. **LiveKit Meeting**
  issues unapproved students a token without the microphone publish source,
  then uses authenticated RoomService UpdateParticipant to add/remove the
  microphone source while preserving camera and screen-share permissions.
  On remote update errors, the trusted classroom state is left unchanged.
  Other providers currently expose **advisory** grants (SDK UI gate only).
  Read state.capabilities.enforcesMicrophone rather than checking the provider
  name. Real LiveKit service interoperability and reconnection/token-rotation
  behavior still require authenticated two-device acceptance tests.
- A new participant ID (a fresh backend join) resets the student's speaking
  grant and raised hand. The previous LiveKit participant's microphone permission
  is revoked before replacement, including identities remembered after reference
  heartbeat pruning; failures reject the join and leave the old
  credential usable for retry. An already absent provider participant counts as
  revoked. A successful revocation remains reflected in classroom state even if
  the subsequent new join fails. Same-participant media network reconnections
  keep their grant. Q&A and attendance history are retained.
- The reference server serializes permissions, classroom snapshots and membership
  lifecycle changes per room, revalidating credentials and targets inside the
  queue. Provider failures release the queue; unrelated rooms proceed independently.
  LiveKit control requests abort after ten seconds. This in-process queue does not
  provide cross-instance locking; production hosts must bind join identities to
  authenticated users and use shared transactional coordination where applicable.
- Student microphone and camera flags are shown only if a media participant
  snapshot reports them. Otherwise the UI says unknown.
- Chat uses the existing ChatSession and its normal unread UI. The classroom
  stats chatMessages field is a local session count, not a server-wide total.
- SDK panels follow the host MaterialApp locale (English or zh); teacher views
  support student search and Q&A search/status filters. The backend retains
  offline roster entries in the room lifecycle. Question pagination, cloud
  persistence, robust server-wide
  message analytics, and real multi-device provider acceptance tests remain
  follow-up work.
- The class only appears for backend-provisioned Meeting rooms. Live rooms and
  direct-credential integrations are unaffected.

## Test commands

~~~sh
cd demo-server && npm test && npm run typecheck
cd ../packages/flutter_realtime_classroom_core && flutter test
cd ../flutter_realtime_classroom_ui && flutter test
cd ../flutter_realtime_sdk_runtime && flutter analyze
cd ../../example && flutter analyze && flutter build web
~~~

## Classroom tools extension

The existing `ClassroomRepository.action(String, data: Map<String,String>)`
contract is unchanged. Extended actions use `tool.*` names and a JSON string
`payload`. A snapshot with no `tools` field remains V1-compatible: its tools
capability is false and the SDK hides the teaching-tools tab.

`ClassroomState.tools` provides immutable notices, homework, materials, timer,
activities and annotation canvas; `ClassroomState.attendance` holds session
presence records. These methods belong to `ClassroomSession`:

```dart
await classroom.publishAnnouncement('Today: fractions');
await classroom.remindFocus('Please focus on the shared screen');
await classroom.publishHomework(title: 'Practice', instructions: 'Solve 1–5');
await classroom.shareMaterial(title: 'Slides', url: 'https://your-app/slides.pdf');
await classroom.startTimer(title: 'Practice', duration: Duration(minutes: 5));
await classroom.publishActivity(
  kind: ClassroomActivityKind.quiz,
  title: '2 + 2 = ?', options: ['3', '4'], correctOption: 1,
);
// Students: await classroom.answerActivity(activityId, 1);
// Teachers: await classroom.closeActivity(activityId);
```

Teachers publish announcements, focus reminders, homework, materials, timers,
Quiz/Poll and annotations. Student activity submissions use the authenticated
logical user identity. Options are single choice (2–8 distinct options); a
student's new answer replaces their previous answer until the teacher closes
the activity. Active Quiz snapshots sent to students omit the correct option,
result counts and individual answers. After close they expose aggregate counts
and the correct option; only teachers receive individual answer mappings.
Poll has no correct-answer field. The Quiz form derives its answer selector
from the entered nonempty options. Removing the selected answer requires a new
selection; invalid options and backend errors retain the form and its input.
Homework is publication/viewing only.

Timers use a server-issued absolute deadline and clamp at zero. Notices appear
in the tools panel and student announcement/focus notifications also appear as
a snackbar. Presence is derived from the reference room directory, leave and
heartbeat expiry; it is not biometric verification or a formal absence record.
Attendance reports first join, last join/leave and accumulated online duration.
Students see only their own attendance; teachers see student records. Stats
separate online participants, online students and students seen this session.
`chatMessages` is explicitly labelled as this device's cached messages.

Materials accept HTTP(S) links and open via the host platform's URL launcher.
There is no file picker, storage service, upload endpoint or document preview
engine in the Demo. Hosts can implement `ClassroomMaterialUploader` and call
`uploadMaterial` to upload through their own infrastructure before sharing its
returned link. Opening a material link is a user action, not a background fetch.

The reference bounds notices/homework/materials to 100 retained entries each
and activities to 100 per room. This extension remains in memory even when the
legacy optional `CLASSROOM_STATE_DIR` store is enabled. No new persistence,
payment or recording service is introduced.

## Screen annotations

`classroom.annotations` is an `AnnotationSession` facade with `canvases`,
`setSource`, `begin`, `append`, `undo` and `clear`. `AnnotationCanvas` identifies
the source participant and a server-created canvas epoch. `AnnotationShape`
supports pen, highlight, circle, arrow and text with normalized points.

`RealtimeRoomView` now delegates content transitions and source changes to
`SharedContentController`; legacy backends retain the former shared-track path.
Its default annotation widget is placed inside the **contained video content
rectangle**, excluding letterboxes. Hosts can instead use the lower-level
`MediaRoomView.screenShareOverlayBuilder`, `ClassroomAnnotationOverlay` and
`AnnotationPainter`. `showAnnotations: false` hides the default overlay.
The toolbar is only editable for teachers sharing their own screen; students
are view-only. The first implementation operates in the SDK preview, not as a
system-wide drawing layer over other desktop applications.

Freehand points are sent in batches every 100 ms, at most 100 points per
request. Reference bounds are 200 shapes and 2,048 points per stroke. Teacher
permissions, tool types and normalized coordinates are checked at the control
plane. Every operation includes the current canvas ID; stale-source operations
are rejected. Undo removes the last shape, clear removes all current shapes,
and changing/stopping the share starts a fresh canvas. New/reconnected clients
load the full current canvas. Real-time hint delivery remains best-effort;
without it the default two-second polling fallback determines remote latency.

LiveKit is the first shared-screen path. Other adapters reuse the overlay when
there is a renderable screen track. Receiver support does not imply that the
same platform can start sharing: existing provider capabilities still decide
which sharing controls are enabled. Browser/native video overlay composition,
orientation changes and reconnect behavior need real remote-pixel validation.
Classroom recording remains deferred.

Platform coverage is distinct from the shared annotation API. LiveKit currently
exposes Android/macOS and desktop-browser capture; iOS uses
`useiOSBroadcastExtension: false` for in-app capture, not a configured cross-app
Broadcast Extension. TRTC exposes Android/iOS capture calls; its full iOS flow
still needs real-device acceptance, and its macOS adapter does not expose
publishing. Native Agora/ARTC/Chime adapters currently do not expose screen
publishing. A receiving client may render a share even when it cannot publish.

See the complete [feature/platform and screen-share matrices](../SDK_CAPABILITY_MATRIX.md#teaching-tools-and-live-interactions)
([Chinese](../SDK_CAPABILITY_MATRIX.zh-CN.md#教学工具与直播互动)) and
[outstanding work/acceptance record](INTERACTION_ACCEPTANCE.md).

## Independent whiteboard and unified content

See [Whiteboard SDK](WHITEBOARD_SDK.md) for the independent Core/UI packages, multi-page whiteboard, unified content menu, screen annotations, synchronization and failure semantics. The teaching Meeting Demo uses the common SDK stage by default.
