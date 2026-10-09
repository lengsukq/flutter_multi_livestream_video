# Whiteboard and shared content SDK

## Package boundaries

`flutter_realtime_whiteboard_core` is pure Dart. It depends on neither media,
Chat nor Classroom. `flutter_realtime_whiteboard_ui` adds Flutter widgets only.
The full SDK and `Realtime` export the public models and widgets.

```dart
final board = WhiteboardSession.local();
await board.start();
// Place WhiteboardView(session: board) in a bounded area.
await board.addPage(title: 'Exercise');
await board.begin(AnnotationShape(
  id: 'example', tool: AnnotationTool.arrow,
  points: [AnnotationPoint(.1, .2), AnnotationPoint(.7, .6)],
), canvasId: board.canvas.canvasId);
// Dispose the session when the host is done with it.
await board.dispose();
```

A custom `WhiteboardRepository` supplies snapshots, a state stream, actions and
close. `MemoryWhiteboardRepository` operates offline. Repositories must validate
identity and edits independently; `canEdit` only controls client affordances.
`WhiteboardSession` serializes actions and provides states/errors and annotation
methods. Each action carries `eventId`, `expectedRevision` and, for drawing,
`pageId`/`canvasId`. A repository must deduplicate matching event IDs and reject
conflicting payloads, stale revisions or inactive/deleted targets.

Initial state has one page; the default maximum is 20. At least one page remains.
Deleting the active page selects its predecessor, otherwise the first page.
Every page retains its marks. Page activation rotates the canvas identity while
preserving shapes, so delayed operations from an earlier activation are rejected.
Snapshots carry the page directory and current canvas only.

## Unified teaching stage

`room.sharedContent` is the SDK's `SharedContentController` for Classroom rooms.
Its `whiteboard`, `screenAnnotations`, `content`, `status`, `statuses`,
`stageUpdates` and `selectMode` are public. `SharedContentStage` can also be used
by hosts independently with their own member/screen widgets.

`RealtimeRoomView` integrates the stage and one **Class content / 课堂内容** menu:
Members, Whiteboard, Share screen. Teachers control content; students follow the
mode and current page. The former screen-share button is replaced only when the
backend declares `tools.content`. The legacy presentation layout entry is hidden
while the unified content menu is active; member grid/speaker layouts remain
available. During the first capability read the new menu stays disabled, so it
does not expose teacher actions before permissions are known. Older backends retain their existing screen
workflow. `showClassroom: false` keeps the lower-level room layout; hosts can
compose the independent components themselves. `showAnnotations: false` hides
screen annotation UI; whiteboard retains its drawing tools.

Whiteboard always uses 16:9 content coordinates. Shared screens use the received
track's aspect ratio. The surface excludes letterboxes. Pan/zoom is local and is
available in navigation mode (and always for students); drawing applies the
inverse view transform before normalizing coordinates. The toolbar stays outside
the transformed canvas. All tools work on both surfaces: pen, highlight, circle,
arrow, text, undo, clear. Freehand requests batch every 100 ms, maximum 100 points;
reference limits are 200 shapes/canvas and 2,048 points/stroke.

Stroke updates are handled inside annotation/whiteboard widgets. The media stage
only invalidates for mode/source changes; camera participant widgets are retained
for pen updates. Content transitions do not call camera or microphone controls.

## Capture and failure semantics

Existing vendor adapters still capture and publish the screen. This SDK unifies
management and preview annotations; it does not capture the OS itself, burn marks
into video frames or provide a system-wide desktop overlay. A receiving platform
may display annotations even when its adapter cannot initiate capture. A local
capture without a renderable preview shows a waiting state instead of an editable
empty video canvas.

Screen → whiteboard/members stops capture before committing content state.
A stop failure preserves screen mode. A successful stop followed by a failed
commit reports the stopped capture and offers a repeatable menu action; capture
is not automatically restarted.

Whiteboard → screen starts system selection/capture first. Cancellation/failure
preserves whiteboard mode. A failed content commit attempts to stop the new share.
Rollback failure explicitly reports that capture remains active; Members/stop
sharing can be retried. Busy state prevents concurrent transitions. There is no
optimistic authoritative mode change. Provider snapshot flags must reflect actual
capture completion for adapter acceptance.

A changed local track/source resets only the screen canvas. Whiteboard pages
survive all mode switches. OS stop events reconcile screen mode to Members.
Source changes that a vendor does not expose in its snapshots cannot be inferred;
that adapter's real-device acceptance must confirm its source identity behavior.

## Classroom repository and compatibility

`ClassroomWhiteboardRepository` delegates to the authenticated classroom control
plane. `tools.content` includes content revision/mode, teacher manage permission,
screen canvas, and whiteboard revision/page directory/current canvas. Commands:

- `tool.content.mode`: mode, content `expectedRevision`, screen source when needed.
- `tool.whiteboard.page.add/select/delete`: board revision and page/title.
- `tool.whiteboard.begin/append/undo/clear`: board revision, page and canvas IDs.

The reference backend checks teacher authority before actions, enforces revisions
and deduplication, and holds inactive pages in room-lifecycle memory. Student
snapshots expose read-only content. IM/RTC frames are revision hints, never state
or authorization. The existing two-second polling fallback, late-join snapshot
and reconnect refresh recover current mode/page/marks. Other classrooms' tool
changes do not alter the whiteboard revision.

Legacy `AnnotationSession`, annotation model imports, `ClassroomAnnotationOverlay`,
`AnnotationPainter` and low-level media sharing remain compatible. Screen and
whiteboard share drawing models/renderer but retain separate canvases.

## Acceptance boundaries

See [interaction acceptance](INTERACTION_ACCEPTANCE.md) for this run's tests and
builds. Web/Android/iOS/macOS use the same state and drawing implementation.
Native capture remains subject to the [provider/platform matrix](../SDK_CAPABILITY_MATRIX.zh-CN.md#教学工具与直播互动).
Actual vendor screen transport, distant pixels, physical orientation changes and
multi-device reconnect still require separate acceptance. No persistence, file
upload/storage, recording, courseware import or video composition is added.
