# Flutter Live Stream Meeting Plugin base on AWS Chime

A Flutter plugin project for iOS, Android and Web for live stream meeting on a widget surface

|             | Android | iOS   | Web    |
|-------------|---------|-------|--------|
| **Support** | SDK 23+ | 15.0+ | NotYet |

The plugin and bundled example require Flutter 3.47.0 or newer.
Android builds use Java 17 and compile against Android API 37. Flutter 3.47 requires Android API
23 or newer, so the 2.0.0 release raises the minimum Android SDK from API 21 to API 23. It also
raises the minimum iOS deployment target from iOS 12 to iOS 15; update the host app's platform
targets before upgrading.


# Preview Images
![Preview1](https://github.com/likeconan/flutter_aws_chime/blob/main/previews/preview1.png)
![Preview2](https://github.com/likeconan/flutter_aws_chime/blob/main/previews/preview2.png)

## Installation

First, add `flutter_aws_chime` as a [dependency in your pubspec.yaml file](https://flutter.dev/using-packages/).

### iOS

Add permissions in Info.plist

<key>NSCameraUsageDescription</key>
<string>The app needs camera permission for video conferencing</string>
<key>NSMicrophoneUsageDescription</key>
<string>Use microphone to start call</string>

### Android

If you are using network-based videos, ensure that the following permission is present in your
Android Manifest file, located in `<project root>/android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## Example

<?code-excerpt "basic.dart (basic-example)"?>
```dart
import 'package:flutter/material.dart';

import 'package:flutter_aws_chime/models/join_info.model.dart';
import 'package:flutter_aws_chime/views/meeting.view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SafeArea(
        child: Scaffold(
          body: MeetingView(
            JoinInfo(
              MeetingInfo.fromJson({
                'MeetingId': '',
                'ExternalMeetingId': '',
                'MediaRegion': 'us-east-1',
                'MediaPlacement': {
                  "AudioFallbackUrl": "",
                  "AudioHostUrl": "",
                  "EventIngestionUrl": "",
                  "ScreenDataUrl": "",
                  "ScreenSharingUrl": "",
                  "ScreenViewingUrl": "",
                  "SignalingUrl": "",
                  "TurnControlUrl": ""
                },
              }),
              AttendeeInfo.fromJson(
                  {"AttendeeId": "", "ExternalUserId": "", "JoinToken": ""}),
            ),
          ),
        ),
      ),
    );
  }
}


```
Furthermore, see the example app for playing around.


## Usage and APIs
Most of useful functions are integrated inside native, so it's easy for you to use without implementing them in flutter code. Please see how to use and the API documentation, if you have any requests you could [create an issue](https://github.com/likeconan/flutter_video_player/issues)

### List functions

|                                         | Android            | iOS                 |
|-----------------------------------------|--------------------|---------------------|
| **Video and Audio**                     | :heavy_check_mark: | :heavy_check_mark:  |
| **Mute self and turn on/off video**     | :heavy_check_mark: | :heavy_check_mark:  |
| **See shared screen content**           | :heavy_check_mark: | :heavy_check_mark:  |
| **Message chat**                        | :heavy_check_mark: | :heavy_check_mark:  |
| **Toggle full screen**                  | :heavy_check_mark: | :heavy_check_mark:  |
| **FullScreen**                          | :heavy_check_mark: | :heavy_check_mark:  |
| **Poster Image**                        | :heavy_check_mark: | :heavy_check_mark:  |
| **Prevent Screen Capture**              | WIP                | WIP                 |
| **Marquee Text**                        | WIP                | WIP                 |


### APIs

#### Meeting events and camera

`MeetingModel.events` is a broadcast stream of typed Chime events. Subscribe before joining to
receive session connection and stop states, connection quality, camera availability, attendee
volume and signal changes, and video tile pause, resume, and size changes. `switchCamera` asks the
native SDK to use the front or back camera and returns `false` if the request cannot be sent to an
active meeting.

```dart
final meeting = MeetingModel();
final events = meeting.events.listen((event) {
  if (event is MeetingSessionEvent) {
    debugPrint('${event.kind} ${event.statusCode ?? ''}');
  }
});

await meeting.switchCamera(CameraPosition.back);
// Cancel the subscription when the screen is disposed.
await events.cancel();
```

The example app logs typed events and has a camera switch control. Its headphones control opens
the existing audio device picker; applications can also use `listAudioDevices()`,
`initialAudioSelection()`, and `updateCurrentDevice(device)` directly.

#### Existing meeting controls

> MeetingView Widget Parameters

**JoinInfo** required

It's required when you use with MeetingView Widget, the JoinInfo model has below attributes

|                       | Type    | Required | Comment   |
|-----------------------|---------|-------|-|
| **MeetingInfo**       | Model   | YES | meeting info from aws_chime_sdk |
| **AttendeeInfo**      | Model   | YES | attendee info from aws_chime_sdk |

How to create meeting info?

You can use @aws-sdk/client-chime-sdk-meetings CreateMeetingCommand to create one, please check out this [link](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/client/chime-sdk-meetings/command/CreateMeetingCommand/)

How to create attendee info?

You can use @aws-sdk/client-chime-sdk-meetings CreateAttendeeCommand to create one, please check out this [link](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/client/chime-sdk-meetings/command/CreateAttendeeCommand/)

## Roadmap

| # | Item | Status |
|---|------|--------|
| 1 | Upgrade Flutter and AWS Chime SDK to the latest versions | Complete in 2.0.0 |
| 2 | Support more APIs from the latest Chime SDK | Complete in 2.0.0 |
| 3 | Add video/audio communication backends besides Chime: Agora, LiveKit, TRTC, ARTC | Planned |
| 4 | Add one-to-many livestreaming: IVS, LiveKit, Agora, TRTC, ARTC | Planned |
