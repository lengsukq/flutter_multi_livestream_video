# MediaPipe Selfie Segmenter model

The SDK-owned Web video-effects pipeline bundles the MediaPipe Selfie
Segmenter landscape model from:

`https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_segmenter_landscape/float16/latest/selfie_segmenter_landscape.tflite`

The MediaPipe selfie-segmentation module is distributed under the Apache
License 2.0 notice.

## Face boundary protection

`blaze_face_short_range.tflite` is copied locally, unchanged, from the already
bundled `trtc-sdk-v5` MediaPipe resource in
`flutter_realtime_sdk/assets/provider_web_runtime/vendors/trtc-assets/mediapipe/`.
No new model is fetched. The MediaPipe Tasks Vision runtime detects faces and
protects a feathered ellipse inside each detected face when person segmentation
misses cheeks or temples. The remaining person/background matte is unchanged.
