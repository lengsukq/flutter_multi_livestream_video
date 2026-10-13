package com.oneplusdream.flutter_realtime_video_effects


import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.view.Surface
import io.flutter.view.TextureRegistry

/** Owns Flutter's texture and Canvas output; never owns capture or inference. */
internal class TextureVideoPreview(
 private val textureEntry: TextureRegistry.SurfaceTextureEntry,
 private val performance: CameraFramePerformance,
) {
 private val surfaceTexture = textureEntry.surfaceTexture()
 private val previewSurface = Surface(surfaceTexture)
 private val previewPaint = Paint(Paint.FILTER_BITMAP_FLAG)
 private var closed = false
 fun configure(width: Int, height: Int) { surfaceTexture.setDefaultBufferSize(width, height) }
    fun draw(bitmap: Bitmap, rotation: Int, mirrored: Boolean) {
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

 fun close() {
   if (closed) return
   closed = true
   try { previewSurface.release() } finally { textureEntry.release() }
 }
}
