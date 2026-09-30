package com.oneplusdream.flutter_realtime_video_effects

/** Keeps a deadline instead of resetting it to each accepted capture time. */
internal class CameraFramePacer(frameRate: Int) {
    private val intervalNs = 1_000_000_000L / frameRate
    private var nextFrameNs = 0L
    fun reset() { nextFrameNs = 0L }
    fun accept(timestampNs: Long): Boolean {
        // Camera timestamps have small jitter, especially at 30 Hz.
        if (nextFrameNs != 0L && timestampNs + 1_000_000L < nextFrameNs) return false
        nextFrameNs = if (nextFrameNs == 0L || timestampNs - nextFrameNs > intervalNs)
            timestampNs + intervalNs else nextFrameNs + intervalNs
        return true
    }
}
