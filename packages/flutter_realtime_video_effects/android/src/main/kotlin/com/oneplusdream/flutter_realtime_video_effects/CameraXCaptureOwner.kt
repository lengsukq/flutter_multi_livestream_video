package com.oneplusdream.flutter_realtime_video_effects


import android.content.Context
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
import java.util.concurrent.ExecutorService

/** Main-thread owner of CameraX use cases. The analyzer executor is borrowed. */
internal class CameraXCaptureOwner(
 private val context: Context,
 private val lifecycleOwner: LifecycleOwner,
 private val width: Int,
 private val height: Int,
 private val executor: ExecutorService,
 deviceId: String?,
 private val isCaptureAllowed: () -> Boolean,
 private val onFrame: (ImageProxy) -> Unit,
 private val onRebound: () -> Unit,
) {
 private var provider: ProcessCameraProvider? = null
 private var analysisUseCase: ImageAnalysis? = null
 @Volatile private var disposed = false
 @Volatile var cameraDeviceId: String = deviceId ?: "front"
   private set
 val ready: Boolean get() = provider != null
 val bound: Boolean get() = analysisUseCase != null
    fun start(onStarted: () -> Unit, onError: (Throwable) -> Unit) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener(
            {
                try {
                    check(!disposed) { "Video source has been disposed." }
                    provider = future.get()
                    if (isCaptureAllowed()) bind()
                    onStarted()
                } catch (error: Throwable) {
                    onError(error)
                }
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    fun bind() {
        check(!disposed) { "Camera capture has been disposed." }
        val provider = this.provider ?: return
        analysisUseCase?.let { it.clearAnalyzer(); provider.unbind(it) }
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
        analysis.setAnalyzer(executor, onFrame)
        val selector = if (cameraDeviceId == "back") {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        onRebound()
        provider.bindToLifecycle(lifecycleOwner, selector, analysis)
        analysisUseCase = analysis
    }

    fun unbind() {
        analysisUseCase?.let { analysis ->
            analysis.clearAnalyzer()
            provider?.unbind(analysis)
        }
        analysisUseCase = null
    }


 fun selectCamera(next: String, rebind: Boolean) {
   check(!disposed) { "Camera capture has been disposed." }
   require(next == "front" || next == "back") { "Unknown camera." }
   val previous = cameraDeviceId
   cameraDeviceId = next
   try { if (rebind) bind() }
   catch (error: Throwable) { cameraDeviceId = previous; if (rebind) bind(); throw error }
 }
 fun close() {
   if (disposed) return
   disposed = true
   try { unbind() } finally { provider = null }
 }
}
