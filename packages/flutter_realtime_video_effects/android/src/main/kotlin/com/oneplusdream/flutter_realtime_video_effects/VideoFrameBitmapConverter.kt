package com.oneplusdream.flutter_realtime_video_effects


import android.graphics.Bitmap
import androidx.camera.core.ImageProxy

/** Processor-thread owner of the reusable capture bitmap. */
internal class VideoFrameBitmapConverter(private val performance: CameraFramePerformance) {
 private var captureBitmap: Bitmap? = null
    fun convert(image: ImageProxy): Bitmap {
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

 fun close() { captureBitmap?.recycle(); captureBitmap = null }
}
