package com.oneplusdream.flutter_realtime_video_effects

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * Covers the parts of the GPU pipeline that are pure arithmetic and can run
 * off-device: the vertical flip applied to `glReadPixels` output, and the
 * cover-fit transform used for a replacement backdrop.
 */
class VideoEffectsGlPipelineTest {

    private fun flipVertically(source: ByteBuffer, width: Int, height: Int): ByteBuffer =
        RgbaReadback.topDown(source, width, height)

    @Test fun nativeReadbackWithUnchangedPositionKeepsAllPixels() {
        val buffer = ByteBuffer.allocateDirect(8)
        // Absolute writes simulate JNI: position stays at zero.
        for (i in 0 until 4) buffer.put(i, 11.toByte())
        for (i in 4 until 8) buffer.put(i, 22.toByte())
        assertEquals(0, buffer.position())
        val result = RgbaReadback.topDown(buffer, 1, 2)
        assertEquals(8, result.remaining())
        assertEquals(22, result.get(0).toInt())
        assertEquals(11, result.get(4).toInt())
    }

    @Test fun reusingALargerReadbackBufferLimitsOutputToTheCurrentFrame() {
        val buffer = ByteBuffer.allocateDirect(8)
        val reusable = ByteBuffer.allocateDirect(32)
        val result = RgbaReadback.topDown(buffer, 1, 2, reusable)
        assertEquals(8, result.remaining())
        assertEquals(reusable, result)
    }

    /** Mirrors the shader's backdrop cover-fit uniforms. */
    private fun coverFit(
        frameWidth: Int,
        frameHeight: Int,
        backdropWidth: Int,
        backdropHeight: Int,
    ): Pair<FloatArray, FloatArray> {
        val scaleX: Float
        val scaleY: Float
        if (backdropWidth > 0 && backdropHeight > 0) {
            val frameAspect = frameWidth.toFloat() / frameHeight
            val backdropAspect = backdropWidth.toFloat() / backdropHeight
            if (backdropAspect > frameAspect) {
                scaleX = frameAspect / backdropAspect
                scaleY = 1f
            } else {
                scaleX = 1f
                scaleY = backdropAspect / frameAspect
            }
        } else {
            scaleX = 1f
            scaleY = 1f
        }
        val offsetX = (1f - scaleX) / 2f
        val offsetY = (1f - scaleY) / 2f
        return floatArrayOf(scaleX, scaleY) to floatArrayOf(offsetX, offsetY)
    }

    @Test fun readbackIsFlippedBackToTopDownForTheProvider() {
        // A 2x2 frame where each row is a distinct value. GL hands the rows
        // back bottom-up, so the flip must restore the original order.
        val width = 2
        val height = 2
        val bottomUp = ByteBuffer.allocateDirect(width * height * 4).order(ByteOrder.nativeOrder())
        // As GL returns it: last image row first.
        bottomUp.put(byteArrayOf(30, 30, 30, 30))
        bottomUp.put(byteArrayOf(40, 40, 40, 40))
        bottomUp.put(byteArrayOf(10, 10, 10, 10))
        bottomUp.put(byteArrayOf(20, 20, 20, 20))
        bottomUp.flip()

        val topDown = flipVertically(bottomUp, width, height)

        assertEquals(10, topDown.get(0).toInt())
        assertEquals(20, topDown.get(4).toInt())
        assertEquals(30, topDown.get(8).toInt())
        assertEquals(40, topDown.get(12).toInt())
        // Position is 0, so a sink reading the frame sees row 0 first.
        assertEquals(0, topDown.position())
    }

    @Test fun flipLeavesAnAlreadyTopDownFrameUnchanged() {
        val width = 1
        val height = 3
        val topDown = ByteBuffer.allocateDirect(width * height * 4).order(ByteOrder.nativeOrder())
        topDown.put(byteArrayOf(1, 1, 1, 1))
        topDown.put(byteArrayOf(2, 2, 2, 2))
        topDown.put(byteArrayOf(3, 3, 3, 3))
        topDown.flip()

        val roundTripped = flipVertically(topDown, width, height)
        // Flipping twice is the identity.
        val back = flipVertically(roundTripped, width, height)
        assertEquals(1, back.get(0).toInt())
        assertEquals(2, back.get(4).toInt())
        assertEquals(3, back.get(8).toInt())
    }

    @Test fun coverFitCropsTheBackdropInsteadOfStretchingIt() {
        // A square backdrop in a 16:9 frame. To cover without stretching, the
        // image is scaled to the frame's width, so the top and bottom are
        // cropped and the centre band is shown.
        val (scale, offset) = coverFit(1280, 720, 720, 720)
        assertEquals(1f, scale[0], 0.0001f)   // full width used
        assertTrue(scale[1] < 1f)             // height cropped
        assertEquals(0f, offset[0], 0.0001f)   // no horizontal offset
        // The crop is centred vertically.
        assertEquals((1f - scale[1]) / 2f, offset[1], 0.0001f)
    }

    @Test fun coverFitKeepsTheBackdropAspectInsideTheFrame() {
        // A 16:9 backdrop in a taller 16:10 frame: the sides are cropped so the
        // backdrop is never stretched to fit.
        val (scale, offset) = coverFit(1280, 800, 1920, 1080)
        // Frame aspect 1.6 < backdrop aspect 1.777 -> crop width, keep height.
        assertEquals(1f, scale[1], 0.0001f)   // full height used
        assertTrue(scale[0] < 1f)             // width cropped
        assertEquals((1f - scale[0]) / 2f, offset[0], 0.0001f)
        assertEquals(0f, offset[1], 0.0001f)
    }

    @Test fun aMissingBackdropDoesNotScaleTheBackground() {
        val (scale, offset) = coverFit(1280, 720, 0, 0)
        assertEquals(1f, scale[0], 0.0001f)
        assertEquals(1f, scale[1], 0.0001f)
        assertEquals(0f, offset[0], 0.0001f)
        assertEquals(0f, offset[1], 0.0001f)
    }
}
