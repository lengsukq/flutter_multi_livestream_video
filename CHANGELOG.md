## 3.0.0

* Redesign the public API around `ChimeMeetingSession` and typed join information, state, events,
  audio devices, and errors. This is a breaking release; v2 API compatibility is not provided.
* Add the optional `ChimeMeetingView`, while leaving join/leave/dispose ownership with the caller.
* Align the Android and iOS method-channel response protocol and use typed native error codes.
* Declare iOS and Android as the only supported meeting platforms and update package metadata.

## 2.0.0

* Require Flutter 3.47.0 or newer.
* Upgrade Android Chime SDK to 0.25.5 and Media to 0.25.4; upgrade iOS Chime SDK to 0.27.4,
  Media to 0.25.4, and MachineLearning to 0.3.3.
* Raise the minimum iOS deployment target to 15.0 and Android minimum SDK to API 23. Flutter 3.47 requires these platform floors; Android previously targeted API 21.
* Add the typed `MeetingModel.events` stream for session, connection, camera, attendee, and video
  tile updates.
* Add `CameraPosition` and `MeetingModel.switchCamera`.
* Document the existing audio device list, selection, and update APIs.

## 0.0.1

* Initial publish, please do not use this

## 1.0.0

* Official release for android and ios, Happy using!

## 1.1.0

* Fix pinch view issue with latest flutter
* Fix mute at first issue
* Fix hide control on tap issue

## 1.1.0+1

* Fix message self send not display issue
