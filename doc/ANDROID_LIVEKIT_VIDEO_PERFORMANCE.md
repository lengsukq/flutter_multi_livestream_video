# Android LiveKit video performance — 2026-10-08

## Report and baseline

- Debug app, image replacement enabled. Pre-join preview was reported smooth;
  video became choppy after joining a LiveKit live session or meeting.
- Connected Android device model: `25128PNA1C`, ABI: `arm64-v8a`.
- Before replacement, `VideoEffectsPerf` showed roughly 4–5 processed frames per
  second during the affected session. Segmentation averaged 28–37 ms and GPU
  composition roughly 4 ms; the old log did not measure provider publication.

## Change

Pre-join preview has no provider frame subscriber. Joining attaches the LiveKit
subscriber, which previously converted RGBA to I420 with Kotlin pixel loops on
the camera processing thread. Replace that conversion with the installed
WebRTC native `YuvHelper.ABGRToI420` path and refcounted `JavaI420Buffer` storage.
Keep the shared source, resolution, timestamps, rotation and background effect.
Validate direct RGBA input and row strides before conversion.

The debug effects log now includes `publish` time. An opt-in `LiveKitFramePerf`
log reports frame size, delivered fps, conversion and capture submission time;
it contains no video pixels or participant data. Enable before joining:

```sh
adb shell setprop log.tag.LiveKitFramePerf DEBUG
adb logcat -v threadtime -s VideoEffectsPerf:I LiveKitFramePerf:D
```

Disable the tag with `adb shell setprop log.tag.LiveKitFramePerf INFO` and rejoin.
The delivered rate measures capture submission, not the remote decoded rate.

## Verification

- Offline Android debug build passed, including the LiveKit Java/native API
  compile against the locally installed WebRTC dependency.
- Existing Android effects unit tests: 32 passed, zero failures/errors.
- Whitespace checks passed.
- Built debug APK installed successfully on the connected device, preserving
  app data, and the app was launched.
- User re-entered LiveKit with image replacement enabled and confirmed the
  picture was smooth after installation. This confirms the reported symptom
  improved on this device in the debug app.

**Pending:** post-install frame-rate and publication timing capture,
remote decoded video and color/orientation comparison. The device
disconnected after installation. Builds and the existing unit tests do not
establish native converter pixel accuracy or a measured performance improvement.

## Follow-up: Chime and screen capture

### Chime Android

The Chime subscriber also called the Kotlin pixel-loop converter. It now uses
`org.amazon.chime.webrtc.YuvHelper.ABGRToI420` from the Chime media dependency
already declared in the project. No new dependency or second RTC runtime was
added. Chime's refcounted frame owns the native I420 allocation until its last
consumer releases it, preserving rotation, timestamps and frame fan-out.

The existing host-JVM forwarding check injects its non-native converter so it
does not attempt to load Android JNI. That check is not native conversion or
performance evidence.

Chime Kotlin compilation and the complete Android debug build passed offline.
No test suite was run for this follow-up. Chime device/provider validation,
pixel accuracy and frame-rate measurement remain pending.

### LiveKit Android screen capture

The user reported that authorization and the sharing notification appeared,
but neither side initially displayed the screen. Retrying on the installed
version succeeded. There is no captured exception that conclusively identifies
the original failure.

Code inspection found a startup race: the native `start` call previously
returned as soon as `Context.startForegroundService` scheduled the service,
before `Service.startForeground` had completed. The call now waits for an
explicit service-ready acknowledgment. Startup failures, cancellation, engine
detachment and a ten-second timeout finish the pending call with an error;
engine detachment also cleans up a service owned by this plugin.

Android requires the media-projection foreground service before capture, and
fresh user consent for each projection session. See the official
[foreground service requirements](https://developer.android.com/develop/background-work/services/fgs/service-types#media-projection)
and [media projection guide](https://developer.android.com/media/grow/media-projection).
The existing fresh-authorization flow and manifest permissions are preserved.

The rebuilt APK has not been installed: the phone disconnected during this
follow-up. Service-ready behavior and repeated screen start/stop need device
validation; the retry on the old installed build does not validate this fix.

### Annotation when switching apps

The current drawing controls and annotation canvas belong to the Demo classroom
page. Switching to another Android app hides that page. An annotation layer that
follows the teacher across apps is not implemented. It requires a separate
Android overlay UI, user-granted overlay access, and a verified path for remote
viewers to see the strokes. See the deferred system-overlay scope in
`INTERACTION_ACCEPTANCE.md`; ordinary classroom whiteboard support is separate.
