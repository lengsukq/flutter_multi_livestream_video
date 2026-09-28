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
