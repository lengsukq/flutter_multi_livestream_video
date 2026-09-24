# Chime Live example

This is the repository's single Flutter demo app. It uses the provider-neutral
Core plus the LiveKit and AWS Chime adapters. The app does **not** choose a
provider: it sends only backend URL, room code, nickname, and role. The
`demo-server` selects the provider for newly-created rooms and returns
short-lived join information.

## Run the example

1. Start the backend by following [`../demo-server/README.md`](../demo-server/README.md).
2. Open the backend dashboard and select LiveKit or AWS Chime for new rooms.
3. Set `MEDIA_BACKEND_URL` (or enter the backend URL in the app) to an address reachable from the test device.
4. Run the app on iOS 15+ or Android API 24+ and create or join a room.
5. Allow microphone and camera access when prompted.

Existing rooms keep their original provider even after the backend dashboard is
switched. The app UI does not expose or require provider selection.

Use Flutter 3.47+, Dart 3.12+, Java 17, and Android compile SDK 37. This local
monorepo example disables Flutter Swift Package Manager and uses CocoaPods on
iOS to avoid local path package-identity ambiguity; the SDK packages themselves
do not require applications to disable SwiftPM.
