# Realtime Media example

This is the repository's single Flutter demo app. It uses the provider-neutral
Core plus the Agora, LiveKit, AWS Chime, Tencent TRTC, and Alibaba Cloud ARTC adapters. The app does **not** choose a
provider: it sends only backend URL, room code, nickname, and role. The
`demo-server` selects the provider for newly-created rooms and returns
short-lived join information.

## Run the example

1. Start the backend by following [`../demo-server/README.md`](../demo-server/README.md).
2. Open the backend dashboard and select a configured provider for new rooms.
3. Set `MEDIA_BACKEND_URL` (or enter the backend URL in the app) to an address reachable from the test device.
4. Run the app on iOS 15+ or Android API 24+ and create or join a room.
5. Allow microphone and camera access when prompted.

Existing rooms keep their original provider even after the backend dashboard is
switched. The app UI does not expose or require provider selection.

Use Flutter 3.47+, Dart 3.12+, Java 17, and Android compile SDK 37. This local
monorepo example disables Flutter Swift Package Manager and uses CocoaPods on
iOS to avoid local path package-identity ambiguity; the SDK packages themselves
do not require applications to disable SwiftPM.

Agora's optional real-service device E2E flow is documented in
[`../AGORA_E2E.md`](../AGORA_E2E.md).

TRTC is an optional adapter package. This reference example registers it to
demonstrate backend-selected providers; applications that do not use TRTC can
omit both `flutter_realtime_media_trtc` and the Tencent SDK dependency. Core
remains vendor-neutral and does not select a default provider. TRTC device E2E
instructions are in [`../TRTC_E2E.md`](../TRTC_E2E.md).

ARTC is also an optional adapter. This reference demo registers it, while apps
that do not use ARTC can omit its package and native SDK. ARTC device E2E
instructions are in [`../ARTC_E2E.md`](../ARTC_E2E.md). The ARTC 7.11.0 iOS pod
does not support simulator linking.
