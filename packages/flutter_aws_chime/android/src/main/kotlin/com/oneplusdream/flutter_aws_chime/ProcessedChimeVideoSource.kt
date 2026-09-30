package com.oneplusdream.flutter_aws_chime

import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoContentHint
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoFrame
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoRotation
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoSink
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoSource
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.buffer.VideoFrameI420Buffer
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrame
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrameHub
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrameSink
import java.nio.ByteBuffer
import java.util.concurrent.CopyOnWriteArraySet

/** Native conversion of the common processed frame; Chime never owns a second camera. */
internal class ProcessedChimeVideoSource(private val sourceId: String) : VideoSource, ProcessedVideoFrameSink {
    private val sinks = CopyOnWriteArraySet<VideoSink>()
    private var disposed = false
    override val contentHint = VideoContentHint.Motion

    init { ProcessedVideoFrameHub.register(sourceId, this) }
    @Synchronized override fun addVideoSink(sink: VideoSink) { if (!disposed) sinks.add(sink) }
    @Synchronized override fun removeVideoSink(sink: VideoSink) { sinks.remove(sink) }

    @Synchronized override fun onVideoFrame(input: ProcessedVideoFrame) {
        if (disposed || sinks.isEmpty()) return
        val width = input.width
        val height = input.height
        val chromaWidth = (width + 1) / 2
        val chromaSize = chromaWidth * ((height + 1) / 2)
        val ySize = width * height
        val data = input.toI420()
        val buffer = VideoFrameI420Buffer(width, height,
            plane(data, 0, ySize), plane(data, ySize, chromaSize), plane(data, ySize + chromaSize, chromaSize),
            width, chromaWidth, chromaWidth, Runnable {})
        val rotation = when (input.rotationDegrees) {
            90 -> VideoRotation.Rotation90
            180 -> VideoRotation.Rotation180
            270 -> VideoRotation.Rotation270
            else -> VideoRotation.Rotation0
        }
        val frame = VideoFrame(input.timestampNs, buffer, rotation)
        try { sinks.forEach { it.onVideoFrameReceived(frame) } }
        finally { frame.release() }
    }

    @Synchronized fun dispose() {
        if (disposed) return
        disposed = true
        ProcessedVideoFrameHub.unregister(sourceId, this)
        sinks.clear()
    }

    private fun plane(data: ByteBuffer, offset: Int, length: Int): ByteBuffer =
        data.duplicate().apply { position(offset); limit(offset + length) }.slice()
}
