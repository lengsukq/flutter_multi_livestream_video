# lite_media

Registers LiveKit only using `RealtimeLite`.
Configure the reference backend to return these providers for the room.

```sh
flutter pub get --offline
flutter run --dart-define=REALTIME_BACKEND_URL=http://localhost:3000
flutter build web --release --no-pub
```

Use HTTPS or localhost on Web. Device deployments must add camera/microphone
permissions and platform targets with the host application's existing setup.
No real credentials or long-lived secrets belong in this example.
