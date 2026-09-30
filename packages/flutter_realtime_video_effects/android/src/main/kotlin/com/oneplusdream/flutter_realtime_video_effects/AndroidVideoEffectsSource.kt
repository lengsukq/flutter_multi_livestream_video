package com.oneplusdream.flutter_realtime_video_effects

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.BitmapFactory
import android.graphics.SurfaceTexture
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.ByteBufferExtractor
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.imagesegmenter.ImageSegmenter
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Shared CameraX capture for local preview and all provider frame sinks.
 * None uses the ordinary camera/Canvas path. Effects use an independent
 * offscreen GPU context, then the same Canvas preview producer.
 */
internal class AndroidVideoEffectsSource(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val sourceId: String,
    private val width: Int,
    private val height: Int,
    val frameRate: Int,
    cameraDeviceId: String?,
    effectType: String,
    blurStrength: String,
    backgroundImageBytes: ByteArray?,
    private val textureEntry: TextureRegistry.SurfaceTextureEntry,
    private val onFailure: (Throwable) -> Unit,
) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val enabled = AtomicBoolean(true)
    private val requestedEnabled = AtomicBoolean(true)
    private val processingFailed = AtomicBoolean(false)
    private val stateLock = Any()
    private val sourceErrorHandler: (Throwable) -> Unit = ::handleSourceFailure
    @Volatile private var disposed = false
    private val framePacer = CameraFramePacer(frameRate)
    private val performance = CameraFramePerformance(
        context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0,
    )
    private var captureBitmap: Bitmap? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var imageAnalysis: ImageAnalysis? = null
    private var cameraDeviceId: String = cameraDeviceId ?: "front"
    @Volatile private var effectType: String = "none"
    @Volatile private var blurStrength: String = blurStrength
    @Volatile private var replacementImage: Bitmap? = null

    private val surfaceTexture: SurfaceTexture = textureEntry.surfaceTexture()
    private val previewSurface = Surface(surfaceTexture)
    private val previewPaint = Paint(Paint.FILTER_BITMAP_FLAG)
    private val glRenderer = VideoEffectsGlRenderer()
    private var processedBitmap: Bitmap? = null
    private var plainPixels: ByteBuffer? = null
    private val effectGeneration = AtomicInteger()
    private data class Matte(val rgba: ByteBuffer, val width: Int, val height: Int, val generation: Int)

    @Volatile private var cachedMask: Matte? = null

    private var segmenter: ImageSegmenter? = null

    private fun ensureSegmenter() {
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

    @Volatile var outputWidth: Int = width
        private set
    @Volatile var outputHeight: Int = height
        private set

    init {
        ProcessedVideoFrameHub.registerSourceErrorHandler(sourceId, sourceErrorHandler)
        try {
            require(width in 1..4096 && height in 1..4096 && frameRate in 1..60) {
                "Invalid video source dimensions or frame rate."
            }
            require(this.cameraDeviceId == "front" || this.cameraDeviceId == "back") {
                "Unknown camera: ${this.cameraDeviceId}"
            }
            setEffect(effectType, blurStrength, backgroundImageBytes)
        } catch (error: Throwable) {
            synchronized(stateLock) { disposed = true }
            ProcessedVideoFrameHub.unregisterSourceErrorHandler(sourceId, sourceErrorHandler)
            try {
                executor.submit {
                    segmenter?.close()
                    segmenter = null
                    glRenderer.release()
                }.get()
            } finally {
                executor.shutdown()
                previewSurface.release()
                textureEntry.release()
            }
            throw error
        }
    }

    fun start(onStarted: () -> Unit, onError: (Throwable) -> Unit) {
        // Size the preview surface synchronously, before anything draws into
        // it. `SurfaceTexture` accepts the size immediately; a producer would
        // only create its surface later, and drawing before that yields nothing.
        surfaceTexture.setDefaultBufferSize(width, height)
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener(
            {
                try {
                    check(!disposed) { "Video source has been disposed." }
                    cameraProvider = future.get()
                    bindCamera()
                    onStarted()
                } catch (error: Throwable) {
                    onError(error)
                }
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    fun setEffect(type: String, strength: String, imageBytes: ByteArray? = null) {
        require(type in setOf("none", "blur", "replaceImage")) {
            "Unsupported background effect: $type"
        }
        check(!disposed) { "Video source has been disposed." }
        val wasEnabled = requestedEnabled.get()
        enabled.set(false)
        try {
            // Decoding and segmenter setup run on the calling thread rather
            // than on the analyzer executor. Queueing this behind the in-flight
            // frame used to block the platform thread for a whole segmentation
            // pass, freezing the UI on every effect change. Nothing here
            // mutates per-frame state: a segmenter is only created while it is
            // still null, so no running frame can be using it.
            var nextImage: Bitmap? = null
            try {
                if (type == "replaceImage") {
                    require(imageBytes != null && imageBytes.isNotEmpty()) {
                        "Background image is required."
                    }
                    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, bounds)
                    require(bounds.outWidth in 1..4096 && bounds.outHeight in 1..4096) {
                        "Invalid background image dimensions."
                    }
                    nextImage = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                    require(nextImage != null) { "Invalid background image." }
                }
                if (type != "none") ensureSegmenter()
            } catch (error: Throwable) {
                ProcessedVideoFrameHub.reportSourceFailure(sourceId, error)
                throw error
            }
            // The outgoing bitmap is dropped rather than recycled: the analyzer
            // may still be uploading it in the frame in flight, and recycling it
            // underneath would crash the effect mid-call.
            replacementImage = nextImage
            effectType = type
            blurStrength = strength
            effectGeneration.incrementAndGet()
            cachedMask = null
            processingFailed.set(false)
            enabled.set(wasEnabled)
            ProcessedVideoFrameHub.resetSourceFailure(sourceId)
        } catch (error: Throwable) {
            enabled.set(wasEnabled)
            throw error
        }
        // A previous failure releases capture. A valid replacement effect can
        // resume the requested camera state without an extra camera toggle.
        if (wasEnabled && cameraProvider != null && imageAnalysis == null) {
            try {
                bindCamera()
            } catch (error: Throwable) {
                ProcessedVideoFrameHub.reportSourceFailure(sourceId, error)
                throw error
            }
        }
    }

    fun setEnabled(value: Boolean) {
        check(!disposed) { "Video source has been disposed." }
        check(!value || !processingFailed.get()) {
            "Recover the video processor before enabling the camera."
        }
        if (value) {
            if (imageAnalysis == null) bindCamera()
            requestedEnabled.set(true)
            enabled.set(true)
        } else {
            requestedEnabled.set(false)
            enabled.set(false)
            unbindCamera()
        }
    }

    fun selectCamera(deviceId: String?) {
        val next = deviceId ?: "front"
        require(next == "front" || next == "back") { "Unknown camera: $next" }
        val previous = cameraDeviceId
        cameraDeviceId = next
        effectGeneration.incrementAndGet()
        cachedMask = null
        check(!disposed) { "Video source has been disposed." }
        try {
            if (enabled.get()) bindCamera()
        } catch (error: Throwable) {
            cameraDeviceId = previous
            if (enabled.get()) bindCamera()
            throw error
        }
    }

    private fun bindCamera() {
        val provider = cameraProvider ?: return
        imageAnalysis?.let { it.clearAnalyzer(); provider.unbind(it) }
        val analysis = ImageAnalysis.Builder()
            // CameraX reports the clockwise display rotation in ImageInfo;
            // target rotation alone does not rotate the captured pixel buffer.
            .setResolutionSelector(
                ResolutionSelector.Builder()
                    .setAspectRatioStrategy(
                        AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY,
                    )
                    .setResolutionStrategy(
                        ResolutionStrategy(
                            android.util.Size(width, height),
                            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
                        ),
                    )
                    .build(),
            )
            .setTargetRotation(Surface.ROTATION_0)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
        analysis.setAnalyzer(executor, ::processFrame)
        val selector = if (cameraDeviceId == "back") {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        framePacer.reset()
        provider.bindToLifecycle(lifecycleOwner, selector, analysis)
        imageAnalysis = analysis
    }

    private fun unbindCamera() {
        imageAnalysis?.let { analysis ->
            analysis.clearAnalyzer()
            cameraProvider?.unbind(analysis)
        }
        imageAnalysis = null
    }

    private fun stopCameraAfterFailure() {
        ContextCompat.getMainExecutor(context).execute {
            if (!disposed && processingFailed.get()) unbindCamera()
        }
    }

    private fun handleSourceFailure(error: Throwable) {
        android.util.Log.e("VideoEffects", "Source failure: $error", error)
        synchronized(stateLock) {
            if (disposed) return
            processingFailed.set(true)
            enabled.set(false)
            stopCameraAfterFailure()
            try {
                onFailure(error)
            } catch (callbackError: Throwable) {
                android.util.Log.e(
                    "VideoEffects",
                    "Could not notify Flutter about a source failure.",
                    callbackError,
                )
            }
        }
    }

    private fun processFrame(image: ImageProxy) {
        val generation = effectGeneration.get()
        performance.startFrame(effectType)
        var presented = false
        try {
            if (disposed || !enabled.get()) return
            val timestampNs = image.imageInfo.timestamp
            if (!framePacer.accept(timestampNs)) return
            val effect = effectType
            val rotation = image.imageInfo.rotationDegrees
            val mirrored = cameraDeviceId != "back"

            // Plain camera preview: no segmenter, GL context, matte or effect.
            if (effect == "none") {
                val bitmap = cameraBitmap(image)
                run {
                    if (disposed || !enabled.get() || generation != effectGeneration.get()) return
                    drawPreview(bitmap, rotation, mirrored)
                    presented = true
                    outputWidth = image.width
                    outputHeight = image.height
                    if (ProcessedVideoFrameHub.hasSubscribers(sourceId)) {
                        val size = bitmap.byteCount
                        val pixels = plainPixels?.takeIf { it.capacity() >= size }
                            ?: ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())
                                .also { plainPixels = it }
                        pixels.clear()
                        bitmap.copyPixelsToBuffer(pixels)
                        pixels.flip()
                        publishFrame(pixels, image.width, image.height, timestampNs, rotation)
                    }
                }
                return
            }

            val plane = image.planes[0]
            require(plane.pixelStride == 4) {
                "Unsupported capture pixel stride: ${plane.pixelStride}"
            }
            // Use the matte from this exact capture, avoiding a stale outline
            // when the person moves between frames.
            val nextMask = segmentMatte(image, timestampNs / 1_000_000L, generation)
            if (generation != effectGeneration.get()) return
            cachedMask = nextMask
            val matte = cachedMask?.takeIf { it.generation == generation }
            val gpuStartNs = System.nanoTime()
            val rendered = glRenderer.render(
                frame = plane.buffer,
                frameWidth = image.width,
                frameHeight = image.height,
                rowStride = plane.rowStride,
                mask = matte?.rgba,
                maskWidth = matte?.width ?: 0,
                maskHeight = matte?.height ?: 0,
                backdrop = if (effect == "replaceImage") replacementImage else null,
                effectType = effect,
                rotationDegrees = rotation,
                // Mirror only the local preview after applying camera rotation.
                mirrored = false,
                blurDivisor = blurDivisorFor(blurStrength),
            )
            performance.stage("gpu", System.nanoTime() - gpuStartNs)
            if (disposed || !enabled.get() || generation != effectGeneration.get()) return
            val bitmap = processedBitmap?.takeIf {
                it.width == rendered.width && it.height == rendered.height
            } ?: Bitmap.createBitmap(rendered.width, rendered.height, Bitmap.Config.ARGB_8888)
                .also { processedBitmap?.recycle(); processedBitmap = it }
            bitmap.copyPixelsFromBuffer(rendered.pixels.duplicate())
            drawPreview(bitmap, rotation, mirrored)
            presented = true
            outputWidth = rendered.width
            outputHeight = rendered.height
            if (ProcessedVideoFrameHub.hasSubscribers(sourceId)) {
                publishFrame(rendered.pixels, rendered.width, rendered.height, timestampNs, rotation)
            }
        } catch (error: Throwable) {
            if (!disposed && generation == effectGeneration.get()) {
                android.util.Log.e("VideoEffects", "Frame render failed: $error", error)
                ProcessedVideoFrameHub.reportSourceFailure(sourceId, error)
            }
        } finally {
            image.close()
            performance.endFrame(presented)
        }
    }

    private fun publishFrame(pixels: ByteBuffer, width: Int, height: Int, timestampNs: Long, rotation: Int) {
        ProcessedVideoFrameHub.publish(
            ProcessedVideoFrame(
                sourceId = sourceId, rgba = pixels, width = width, height = height,
                timestampNs = timestampNs, rotationDegrees = rotation, mirrored = false,
            ),
        )
    }

    private fun cameraBitmap(image: ImageProxy): Bitmap {
        val startedNs = System.nanoTime()
        val plane = image.planes[0]
        require(plane.pixelStride == 4)
        val bitmap = captureBitmap?.takeIf { it.width == image.width && it.height == image.height }
            ?: Bitmap.createBitmap(image.width, image.height, Bitmap.Config.ARGB_8888)
                .also { captureBitmap?.recycle(); captureBitmap = it }
        if (plane.rowStride == image.width * 4) {
            val pixels = plane.buffer.duplicate().apply { position(0); limit(image.width * image.height * 4) }
            bitmap.copyPixelsFromBuffer(pixels)
        } else {
            // Preserve correctness on devices that pad camera rows.
            val converted = image.toBitmap()
            try { android.graphics.Canvas(bitmap).drawBitmap(converted, 0f, 0f, null) }
            finally { converted.recycle() }
        }
        performance.stage("copy", System.nanoTime() - startedNs)
        return bitmap
    }

    private fun drawPreview(bitmap: Bitmap, rotation: Int, mirrored: Boolean) {
        val startedNs = System.nanoTime()
        // Use one hardware Canvas producer for every mode. The effect renderer
        // remains on a separate offscreen surface; None only draws raw pixels.
        val canvas = previewSurface.lockHardwareCanvas()
        try {
            canvas.drawColor(Color.BLACK)
            val scale = CameraPreviewFit.containScale(
                bitmap.width, bitmap.height, rotation, canvas.width, canvas.height,
            )
            val matrix = Matrix().apply {
                postTranslate(-bitmap.width / 2f, -bitmap.height / 2f)
                postRotate(rotation.toFloat())
                postScale(if (mirrored) -scale else scale, scale)
                postTranslate(canvas.width / 2f, canvas.height / 2f)
            }
            canvas.drawBitmap(bitmap, matrix, previewPaint)
        } finally {
            previewSurface.unlockCanvasAndPost(canvas)
            performance.stage("draw", System.nanoTime() - startedNs)
        }
    }

    private fun blurDivisorFor(strength: String): Int = when (strength) {
        "low" -> 6
        "high" -> 14
        else -> 10
    }

    /**
     * Runs MediaPipe over the frame and caches the refined matte as tightly
     * packed RGBA whose alpha channel is the person mask. The renderer uploads
     * it directly as a texture.
     */
    private fun segmentMatte(image: ImageProxy, timestampMs: Long, generation: Int): Matte? {
        val startedNs = System.nanoTime()
        val capture = cameraBitmap(image)
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
                return Matte(rgba, sensor.width, sensor.height, generation)
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

    fun dispose() {
        val shouldDispose = synchronized(stateLock) {
            if (disposed) false else {
                disposed = true
                enabled.set(false)
                true
            }
        }
        if (!shouldDispose) return
        ProcessedVideoFrameHub.unregisterSourceErrorHandler(sourceId, sourceErrorHandler)
        unbindCamera()
        ProcessedVideoFrameHub.clear(sourceId)
        try {
            // `stateLock` must not be held across this `.get()`: the GL teardown
            // runs on the same single thread the analyzer uses.
            executor.submit {
                segmenter?.close()
                segmenter = null
                cachedMask = null
                replacementImage = null
                glRenderer.release()
                processedBitmap?.recycle()
                processedBitmap = null
                captureBitmap?.recycle()
                captureBitmap = null
            }.get()
        } finally {
            executor.shutdown()
            previewSurface.release()
            textureEntry.release()
        }
    }
}
