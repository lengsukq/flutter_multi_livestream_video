# Windows person segmentation model

This plugin uses OpenCV Zoo's **PPHumanSeg** ONNX person segmentation model
(192x192, float32 NCHW RGB, two output classes, Apache-2.0).

Model: `human_segmentation_pphumanseg_2023mar.onnx`

Source: https://huggingface.co/opencv/opencv_zoo/resolve/main/models/human_segmentation_pphumanseg/human_segmentation_pphumanseg_2023mar.onnx

Pinned SHA-256: `552d8a984054e59b5d773d24b9b12022b22046ceb2bbc4c9aaeaceb36a9ddf24`

Copyright and license: OpenCV Zoo human segmentation model directory,
https://github.com/opencv/opencv_zoo/tree/main/models/human_segmentation_pphumanseg
Apache License 2.0. Preserve its license and attribution in redistributed
packages. Validate the model hash before using it. Do not redistribute without
also packaging the corresponding license notices.

Runtime: ONNX Runtime C++ (CPU by default). The Windows CMake integration
requires an explicitly configured ONNX Runtime distribution; model and runtime
availability must be probed at startup, not assumed. On an unsupported
Windows machine, `isSupported` must return false and virtual background
must not activate. Never replace an inference failure with the raw camera.
