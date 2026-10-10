# Pre-Join setup

MediaClient.runPreJoinCheck() validates backend reachability, provider
availability, microphone and camera permission status, device availability,
and basic network readiness before creating or joining a room.

Required permission or device checks block when they fail, are unsupported, or
cannot be determined. Recommended checks remain warnings. Skipped checks are
omitted.

The /health endpoint is diagnostic-only. A backend that does not implement
GET /health remains compatible. HTTP 404/unsupported diagnostics are
non-blocking. Any HTTP response proves the basic network path is reachable, but
an implemented health endpoint returning a real backend failure such as 5xx is
still a blocking backend-health failure. Connection failures and timeouts are
blocking network failures.

## Camera and microphone permissions

The default MediaPermissionProbe uses permission_handler only to read the
current camera and microphone permission status. It never requests permission.

Android host applications must compile with Android compileSdk 37 or newer and
declare android.permission.CAMERA and android.permission.RECORD_AUDIO when
those media features are used.

iOS CocoaPods host applications must provide NSCameraUsageDescription and
NSMicrophoneUsageDescription in Info.plist. They must also enable
PERMISSION_CAMERA=1 and PERMISSION_MICROPHONE=1 in the Podfile post_install
GCC_PREPROCESSOR_DEFINITIONS for permission_handler_apple.

The repository example app contains matching Android manifest, iOS usage
description, and Podfile configuration.

### macOS and other desktop hosts

`permission_handler` does not reliably report camera/microphone TCC status on
macOS through this project's default permission probe. For desktop targets,
the probe returns `MediaPermissionState.unknown` (not `unsupported`), because
an unreadable permission status is not evidence that a physical device or
provider SDK cannot capture. Pre-Join permission checks remain advisory under
the default recommended media requirements. Confirm real access by enabling
the camera/microphone in the preview or by a provider capture test.

macOS host applications need `NSCameraUsageDescription` and
`NSMicrophoneUsageDescription` in their Runner Info.plist, and sandboxed apps
need the `com.apple.security.device.camera` and
`com.apple.security.device.audio-input` entitlements in both DebugProfile and
Release configurations. The example app already declares these. macOS may
show an OS permission prompt when the capture API first starts; if it was
previously denied, review System Settings > Privacy & Security > Camera /
Microphone for the application. Capture support ultimately depends on the
selected provider's desktop adapter and available hardware.
