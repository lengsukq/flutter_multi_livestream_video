package com.oneplusdream.flutter_realtime_video_effects
import com.oneplusdream.flutter_realtime_processed_video.ProcessedVideoFrameHub
import com.oneplusdream.flutter_realtime_processed_video.ProcessedVideoSourceControls


import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import androidx.camera.core.ImageProxy
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
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
    @Volatile private var effectType: String = "none"
    @Volatile private var blurStrength: String = blurStrength
    @Volatile private var replacementImage: Bitmap? = null

    private val glRenderer = VideoEffectsGlRenderer()
    private var processedBitmap: Bitmap? = null
    private var plainPixels: ByteBuffer? = null
    private val effectGeneration = AtomicInteger()


    private val converter = VideoFrameBitmapConverter(performance)
    private val segmenter = PersonVideoSegmenter(context, converter, performance)
    private val preview = TextureVideoPreview(textureEntry, performance)
    private val dispatcher = ProcessedFrameDispatcher(sourceId, performance)
    private val capture = CameraXCaptureOwner(
        context, lifecycleOwner, width, height, executor, cameraDeviceId,
        isCaptureAllowed = { !disposed && enabled.get() },
        onFrame = ::processFrame, onRebound = framePacer::reset,
    )
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
            require(capture.cameraDeviceId == "front" || capture.cameraDeviceId == "back") {
                "Unknown camera: ${capture.cameraDeviceId}"
            }
            setEffect(effectType, blurStrength, backgroundImageBytes)
        } catch (error: Throwable) {
            synchronized(stateLock) { disposed = true }
            ProcessedVideoFrameHub.unregisterSourceErrorHandler(sourceId, sourceErrorHandler)
            try {
                executor.submit {
                    segmenter.close()
                    glRenderer.release()
                }.get()
            } finally {
                executor.shutdown()
                preview.close()
            }
            throw error
        }
    }

    init { ProcessedVideoSourceControls.register(sourceId, ::setEnabled, ::selectCamera) }

    fun start(onStarted: () -> Unit, onError: (Throwable) -> Unit) {
        preview.configure(width, height)
        capture.start(onStarted, onError)
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
                if (type != "none") segmenter.ensureReady()
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
            processingFailed.set(false)
            enabled.set(wasEnabled)
            ProcessedVideoFrameHub.resetSourceFailure(sourceId)
        } catch (error: Throwable) {
            enabled.set(wasEnabled && !processingFailed.get())
            throw error
        }
        // A previous failure releases capture. A valid replacement effect can
        // resume the requested camera state without an extra camera toggle.
        if (wasEnabled && capture.ready && !capture.bound) {
            try {
                capture.bind()
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
            if (!capture.bound) capture.bind()
            requestedEnabled.set(true)
            enabled.set(true)
        } else {
            requestedEnabled.set(false)
            enabled.set(false)
            capture.unbind()
        }
    }

    fun selectCamera(deviceId: String?) {
        check(!disposed) { "Video source has been disposed." }
        effectGeneration.incrementAndGet()
        capture.selectCamera(deviceId ?: "front", rebind = enabled.get())
    }

    private fun stopCameraAfterFailure() {
        ContextCompat.getMainExecutor(context).execute {
            if (!disposed && processingFailed.get()) capture.unbind()
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
            val mirrored = capture.cameraDeviceId != "back"

            // Plain camera preview: no segmenter, GL context, matte or effect.
            if (effect == "none") {
                val bitmap = converter.convert(image)
                run {
                    if (disposed || !enabled.get() || generation != effectGeneration.get()) return
                    preview.draw(bitmap, rotation, mirrored)
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
                        dispatcher.publish(pixels, image.width, image.height, timestampNs, rotation)
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
            val nextMask = segmenter.segment(image, timestampNs / 1_000_000L, generation)
            if (generation != effectGeneration.get()) return
            val matte = nextMask?.takeIf { it.generation == generation }
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
            preview.draw(bitmap, rotation, mirrored)
            presented = true
            outputWidth = rendered.width
            outputHeight = rendered.height
            if (ProcessedVideoFrameHub.hasSubscribers(sourceId)) {
                dispatcher.publish(rendered.pixels, rendered.width, rendered.height, timestampNs, rotation)
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

    private fun blurDivisorFor(strength: String): Int = when (strength) {
        "low" -> 6
        "high" -> 14
        else -> 10
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
        val cleanup = NativeResourceCleanup()
        cleanup.run("source.handler") { ProcessedVideoFrameHub.unregisterSourceErrorHandler(sourceId, sourceErrorHandler) }
        cleanup.run("source.controls") { ProcessedVideoSourceControls.unregister(sourceId) }
        cleanup.run("capture") { capture.close() }
        cleanup.run("frame.hub") { ProcessedVideoFrameHub.clear(sourceId) }
        cleanup.run("processor") {
            // Capture is stopped first. Processor resources are released on
            // their owner thread, and its in-flight frame drains before preview.
            executor.submit {
                val processorCleanup = NativeResourceCleanup()
                processorCleanup.run("segmenter") { segmenter.close() }
                replacementImage = null
                processorCleanup.run("renderer") { glRenderer.release() }
                processorCleanup.run("processed.bitmap") { processedBitmap?.recycle(); processedBitmap = null }
                processorCleanup.run("capture.bitmap") { converter.close() }
                processorCleanup.finish()
            }.get()
        }
        cleanup.run("executor") { executor.shutdown() }
        cleanup.run("preview") { preview.close() }
        cleanup.finish()
    }
}
