package com.oneplusdream.flutter_realtime_video_effects

import android.content.Context
import com.tencent.trtc.TRTCCloud
import com.tencent.trtc.TRTCCloudDef
import java.nio.ByteBuffer

internal interface NativeProviderSink : ProcessedVideoFrameSink { fun dispose() }
internal object AgoraFramePusher {
    init { System.loadLibrary("realtime_frame_push") }
    external fun create(engineHandle: Long): Long
    external fun push(media: Long, rgba: ByteBuffer, width: Int, height: Int, timestampNs: Long, trackId: Int): Int
    external fun release(media: Long)
}
internal class AgoraProcessedSink(sourceId: String, engine: Long, private val trackId: Int) : NativeProviderSink {
    private val sourceId = sourceId
    private var media = AgoraFramePusher.create(engine)
    init {
        require(media != 0L) { "Agora media engine is unavailable." }
        ProcessedVideoFrameHub.register(sourceId, this)
    }
    @Synchronized override fun onVideoFrame(frame: ProcessedVideoFrame) {
        if (media == 0L) return
        val result = AgoraFramePusher.push(media, frame.rgba, frame.width, frame.height, frame.timestampNs, trackId)
        check(result == 0) { "Agora rejected processed frame: $result" }
    }
    @Synchronized override fun dispose() {
        ProcessedVideoFrameHub.unregister(sourceId, this)
        if (media != 0L) AgoraFramePusher.release(media)
        media = 0
    }
}
internal class TrtcProcessedSink(context: Context, private val sourceId: String) : NativeProviderSink {
    private val cloud = TRTCCloud.sharedInstance(context)
    private var disposed = false
    init {
        cloud.stopLocalPreview()
        cloud.enableCustomVideoCapture(TRTCCloudDef.TRTC_VIDEO_STREAM_TYPE_BIG, true)
        ProcessedVideoFrameHub.register(sourceId, this)
    }
    @Synchronized override fun onVideoFrame(frame: ProcessedVideoFrame) {
        if (disposed) return
        val input = TRTCCloudDef.TRTCVideoFrame().apply {
            pixelFormat = TRTCCloudDef.TRTC_VIDEO_PIXEL_FORMAT_RGBA
            bufferType = TRTCCloudDef.TRTC_VIDEO_BUFFER_TYPE_BYTE_BUFFER
            buffer = frame.rgba; width = frame.width; height = frame.height
            timestamp = frame.timestampNs / 1_000_000; rotation = frame.rotationDegrees / 90
        }
        cloud.sendCustomVideoData(TRTCCloudDef.TRTC_VIDEO_STREAM_TYPE_BIG, input)
    }
    @Synchronized override fun dispose() {
        disposed = true
        ProcessedVideoFrameHub.unregister(sourceId, this)
        cloud.enableCustomVideoCapture(TRTCCloudDef.TRTC_VIDEO_STREAM_TYPE_BIG, false)
    }
}
