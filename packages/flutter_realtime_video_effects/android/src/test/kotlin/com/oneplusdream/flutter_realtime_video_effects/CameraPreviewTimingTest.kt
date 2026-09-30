package com.oneplusdream.flutter_realtime_video_effects

import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class CameraPreviewTimingTest {
    @Test fun twentyFourFpsDoesNotDecimateThirtyFpsCaptureToFifteen() {
        val pacer = CameraFramePacer(24)
        val frames = (0 until 300).count { pacer.accept(1_000_000_000L + it * 33_333_333L) }
        assertTrue(frames in 239..241, "Expected 24 fps over 10 seconds; got $frames frames")
    }
    @Test fun thirtyFpsKeepsCameraFramesWithSmallTimestampJitter() {
        val pacer = CameraFramePacer(30)
        val frames = (0 until 300).count {
            pacer.accept(1_000_000_000L + it * 33_333_333L + if (it % 2 == 0) 0 else -200_000L)
        }
        assertEquals(300, frames)
    }
    @Test fun lowFrameRateCameraIsNotFurtherReduced() {
        val pacer = CameraFramePacer(30)
        assertEquals(150, (0 until 150).count { pacer.accept(1_000_000_000L + it * 66_666_666L) })
    }
    @Test fun portraitPreviewIncludesTheWholeCameraFrame() {
        val scale = CameraPreviewFit.containScale(1280, 720, 270, 1280, 720)
        assertEquals(0.5625f, scale)
        assertTrue(720 * scale <= 1280)
        assertTrue(1280 * scale <= 720)
    }
    @Test fun landscapePreviewIncludesTheWholeCameraFrame() {
        assertEquals(1f, CameraPreviewFit.containScale(1280, 720, 0, 1280, 720))
    }
}
