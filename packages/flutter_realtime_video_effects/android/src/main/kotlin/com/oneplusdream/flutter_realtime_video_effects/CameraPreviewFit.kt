package com.oneplusdream.flutter_realtime_video_effects

internal object CameraPreviewFit {
    fun containScale(width: Int, height: Int, rotation: Int, canvasWidth: Int, canvasHeight: Int): Float {
        val uprightWidth = if (rotation % 180 == 0) width else height
        val uprightHeight = if (rotation % 180 == 0) height else width
        return minOf(canvasWidth.toFloat() / uprightWidth, canvasHeight.toFloat() / uprightHeight)
    }
}
