package com.oneplusdream.flutter_realtime_video_effects


import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import androidx.camera.core.ImageProxy
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.ByteBufferExtractor
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.imagesegmenter.ImageSegmenter
import java.nio.ByteBuffer
import java.nio.ByteOrder

internal data class SegmentedMatte(val rgba: ByteBuffer, val width: Int, val height: Int, val generation: Int)
/** Model ownership; inference/close run on the source's single processor thread. */
internal class PersonVideoSegmenter(
 private val context: Context,
 private val converter: VideoFrameBitmapConverter,
 private val performance: CameraFramePerformance,
) {
 private var segmenter: ImageSegmenter? = null
    fun ensureReady() {
        if (segmenter != null) return
        val options = ImageSegmenter.ImageSegmenterOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath("video-effects/selfie_segmenter_landscape.tflite")
                    .build(),
            )
            // VIDEO mode reuses its internal buffers between frames and needs a
            // monotonically increasing timestamp, which is cheaper than treating
            // every frame as an independent still image.
            .setRunningMode(RunningMode.VIDEO)
            .setOutputCategoryMask(false)
            .setOutputConfidenceMasks(true)
            .build()
        segmenter = ImageSegmenter.createFromOptions(context, options)
    }

    fun segment(image: ImageProxy, timestampMs: Long, generation: Int): SegmentedMatte? {
        val startedNs = System.nanoTime()
        val capture = converter.convert(image)
        // Keep inference and matte refinement at model resolution. MediaPipe's
        // default output mask otherwise expands back to a full camera frame.
        val scale = minOf(1f, 256f / maxOf(capture.width, capture.height))
        val scaled = if (scale < 1f) Bitmap.createScaledBitmap(
            capture, (capture.width * scale).toInt().coerceAtLeast(1),
            (capture.height * scale).toInt().coerceAtLeast(1), true,
        ) else capture
        val rotation = image.imageInfo.rotationDegrees
        // Follow the official Android sample: infer on physically upright
        // pixels. Rotation options alone do not project this task's output
        // mask back to sensor coordinates.
        val bitmap = if (rotation == 0) scaled else Bitmap.createBitmap(
            scaled, 0, 0, scaled.width, scaled.height,
            Matrix().apply { postRotate(rotation.toFloat()) }, true,
        )
        val input = BitmapImageBuilder(bitmap).build()
        try {
            val result = requireNotNull(segmenter).segmentForVideo(input, timestampMs)
            val masks = result.confidenceMasks().orElse(emptyList())
            try {
                val index = PersonConfidenceMatte.foregroundConfidenceMaskIndex(masks.size)
                val maskImage = masks.getOrNull(index ?: -1) ?: return null
                val width = maskImage.width
                val height = maskImage.height
                val confidence = FloatArray(width * height)
                val bytes = ByteBufferExtractor.extract(maskImage).duplicate().order(ByteOrder.nativeOrder())
                bytes.rewind()
                bytes.asFloatBuffer().get(confidence)
                val sensor = CameraMaskGeometry.toSensor(confidence, width, height, rotation)
                val alpha = PersonConfidenceMatte.refine(sensor.confidence, sensor.width, sensor.height)
                val rgba = ByteBuffer.allocateDirect(sensor.width * sensor.height * 4).order(ByteOrder.nativeOrder())
                for (value in alpha) {
                    rgba.put(0.toByte()); rgba.put(0.toByte()); rgba.put(0.toByte())
                    rgba.put((value.coerceIn(0f, 1f) * 255f + 0.5f).toInt().toByte())
                }
                rgba.flip()
                return SegmentedMatte(rgba, sensor.width, sensor.height, generation)
            } finally {
                masks.forEach { it.close() }
            }
        } finally {
            input.close()
            if (bitmap !== capture) bitmap.recycle()
            if (scaled !== bitmap && scaled !== capture) scaled.recycle()
            performance.stage("segment", System.nanoTime() - startedNs)
        }
    }

 fun close() { segmenter?.close(); segmenter = null }
}
