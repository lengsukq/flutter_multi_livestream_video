package com.oneplusdream.flutter_realtime_video_effects
import com.oneplusdream.flutter_realtime_processed_video.ProcessedVideoFrameHub
import com.oneplusdream.flutter_realtime_processed_video.ProcessedVideoFrame


import java.nio.ByteBuffer

/** Synchronous dispatch: sinks must finish consuming this borrowed buffer. */
internal class ProcessedFrameDispatcher(private val sourceId: String, private val performance: CameraFramePerformance) {
    fun publish(pixels: ByteBuffer, width: Int, height: Int, timestampNs: Long, rotation: Int) {
        val startedNs = System.nanoTime()
        ProcessedVideoFrameHub.publish(
            ProcessedVideoFrame(
                sourceId = sourceId, rgba = pixels, width = width, height = height,
                timestampNs = timestampNs, rotationDegrees = rotation, mirrored = false,
            ),
        )
        performance.stage("publish", System.nanoTime() - startedNs)
    }

}
