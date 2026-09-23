# flutter_aws_chime v3 example

This app demonstrates the v3 `ChimeMeetingSession` API, the optional `ChimeMeetingView`, and the backend boundary. The demo backend creates Chime meetings and attendees; the Flutter client receives only short-lived join information.

## Run the example

1. Start the backend by following [`../demo-server/README.md`](../demo-server/README.md). Keep AWS credentials on the backend and use a test account/profile.
2. Set the backend URL to an address reachable from the test device.
3. Run the example app on iOS 15+ or Android API 24+ and create or join a room. The package itself supports Android API 23+; the example's integration-test dependency requires API 24+.
4. Allow microphone and camera access when prompted.

Use Flutter 3.47+, Dart 3.12+, Java 17, and Android compile SDK 37. The example exercises the current v3 API; it does not provide a web or desktop meeting implementation.
