package com.oneplusdream.flutter_aws_chime

import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoContentHint
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoFrame
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoRotation
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.VideoSink
import com.amazonaws.services.chime.sdk.meetings.audiovideo.video.buffer.VideoFrameI420Buffer
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrame
import com.oneplusdream.flutter_realtime_video_effects.ProcessedVideoFrameHub
import java.nio.ByteBuffer
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertSame
import kotlin.test.assertTrue

class ProcessedChimeVideoSourceTest {
    @Test fun forwardsProcessedFrameMetadataAndI420WithoutAnotherCamera() {
        val sourceId = "chime-test-source"
        val source = ProcessedChimeVideoSource(sourceId)
        val received = mutableListOf<VideoFrame>()
        val first = object : VideoSink {
            override fun onVideoFrameReceived(frame: VideoFrame) { frame.retain(); received.add(frame) }
        }
        val second = object : VideoSink {
            override fun onVideoFrameReceived(frame: VideoFrame) { frame.retain(); received.add(frame) }
        }
        try {
            source.addVideoSink(first); source.addVideoSink(second)
            val bytes = ByteBuffer.allocateDirect(3 * 3 * 4)
            repeat(9) { bytes.put(byteArrayOf(-1, 0, 0, -1)) }; bytes.rewind()
            ProcessedVideoFrameHub.publish(ProcessedVideoFrame(sourceId, bytes, 3, 3, 4000123456L, 90))
            assertEquals(VideoContentHint.Motion, source.contentHint)
            assertEquals(2, received.size)
            assertSame(received[0], received[1])
            val frame = received[0]
            assertEquals(4000123456L, frame.timestampNs)
            assertEquals(VideoRotation.Rotation90, frame.rotation)
            val buffer = frame.buffer as VideoFrameI420Buffer
            assertEquals(3, buffer.width); assertEquals(3, buffer.height)
            assertEquals(3, buffer.strideY); assertEquals(2, buffer.strideU)
            assertTrue(buffer.dataY.isDirect)
            assertEquals(82, buffer.dataY.get(0).toInt() and 255)
            assertEquals(90, buffer.dataU.get(0).toInt() and 255)
            assertEquals(240, buffer.dataV.get(0).toInt() and 255)
            received.forEach { it.release() }; received.clear()
            source.removeVideoSink(first)
            ProcessedVideoFrameHub.publish(ProcessedVideoFrame(sourceId, bytes, 3, 3, 4001123456L))
            assertEquals(1, received.size)
            source.dispose()
            ProcessedVideoFrameHub.publish(ProcessedVideoFrame(sourceId, bytes, 3, 3, 4002123456L))
            assertEquals(1, received.size)
        } finally {
            received.forEach { it.release() }
            source.dispose()
        }
    }
}
