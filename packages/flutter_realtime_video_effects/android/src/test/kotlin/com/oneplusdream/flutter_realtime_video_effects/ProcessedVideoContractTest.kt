package com.oneplusdream.flutter_realtime_video_effects

import java.nio.ByteBuffer
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertSame
import kotlin.test.assertTrue

class ProcessedVideoContractTest {
    @Test fun selectsForegroundMaskForSingleAndMulticlassSegmenters() {
        assertEquals(null, PersonConfidenceMatte.foregroundConfidenceMaskIndex(0))
        assertEquals(0, PersonConfidenceMatte.foregroundConfidenceMaskIndex(1))
        assertEquals(1, PersonConfidenceMatte.foregroundConfidenceMaskIndex(2))
        assertEquals(1, PersonConfidenceMatte.foregroundConfidenceMaskIndex(3))
    }

    @Test fun fanOutPreservesMetadataAndSharesReadOnlyPixels() {
        val id = "contract-source"
        val bytes = ByteBuffer.allocateDirect(4).apply { put(byteArrayOf(12, 34, 56, -1)); rewind() }
        val frames = mutableListOf<ProcessedVideoFrame>()
        val first = ProcessedVideoFrameSink { frames.add(it) }
        val second = ProcessedVideoFrameSink { frames.add(it) }
        ProcessedVideoFrameHub.register(id, first)
        ProcessedVideoFrameHub.register(id, second)
        try {
            ProcessedVideoFrameHub.publish(ProcessedVideoFrame(id, bytes, 1, 1, 123456789, 90, mirrored = true))
            assertEquals(2, frames.size)
            frames.forEach {
                assertEquals(id, it.sourceId); assertEquals(123456789L, it.timestampNs)
                assertEquals(90, it.rotationDegrees); assertEquals(4, it.rowStride)
                assertEquals("rgba8888", it.pixelFormat); assertTrue(it.mirrored)
                assertTrue(it.rgba.isReadOnly)
                assertEquals(12, it.rgba.get(0).toInt())
            }
            bytes.put(0, 45)
            assertEquals(45, frames[0].rgba.get(0).toInt())
            assertEquals(45, frames[1].rgba.get(0).toInt())
            ProcessedVideoFrameHub.unregister(id, first)
            ProcessedVideoFrameHub.clear(id)
            ProcessedVideoFrameHub.publish(ProcessedVideoFrame(id, bytes, 1, 1, 123456790))
            assertEquals(2, frames.size)
        } finally { ProcessedVideoFrameHub.clear(id) }
    }

    @Test fun providerSinkFailureNotifiesSourceOnceAndStopsTheFrameFanOut() {
        val id = "failing-provider-source"
        val rgba = ByteBuffer.allocateDirect(4).apply { put(byteArrayOf(1, 2, 3, -1)); rewind() }
        val providerError = IllegalStateException("Provider rejected the processed frame.")
        val errors = mutableListOf<Throwable>()
        var laterSinkFrames = 0
        val errorHandler: (Throwable) -> Unit = { errors.add(it) }
        val failingSink = ProcessedVideoFrameSink { throw providerError }
        val laterSink = ProcessedVideoFrameSink { laterSinkFrames++ }

        ProcessedVideoFrameHub.registerSourceErrorHandler(id, errorHandler)
        ProcessedVideoFrameHub.register(id, failingSink)
        ProcessedVideoFrameHub.register(id, laterSink)
        try {
            ProcessedVideoFrameHub.publish(ProcessedVideoFrame(id, rgba, 1, 1, 1))
            ProcessedVideoFrameHub.publish(ProcessedVideoFrame(id, rgba, 1, 1, 2))

            assertEquals(1, errors.size)
            assertSame(providerError, errors.single())
            assertEquals(0, laterSinkFrames)
        } finally {
            ProcessedVideoFrameHub.clear(id)
        }
    }

    @Test fun replacingSourceErrorHandlerDoesNotCallTheUnregisteredHandler() {
        val id = "replaced-error-handler-source"
        val oldErrors = mutableListOf<Throwable>()
        val newErrors = mutableListOf<Throwable>()
        val oldHandler: (Throwable) -> Unit = { oldErrors.add(it) }
        val newHandler: (Throwable) -> Unit = { newErrors.add(it) }
        val failure = IllegalStateException("source failed")

        ProcessedVideoFrameHub.registerSourceErrorHandler(id, oldHandler)
        ProcessedVideoFrameHub.unregisterSourceErrorHandler(id, oldHandler)
        ProcessedVideoFrameHub.registerSourceErrorHandler(id, newHandler)
        try {
            ProcessedVideoFrameHub.reportSourceFailure(id, failure)

            assertTrue(oldErrors.isEmpty())
            assertEquals(1, newErrors.size)
            assertSame(failure, newErrors.single())
        } finally {
            ProcessedVideoFrameHub.clear(id)
        }
    }

    @Test fun rgbaConversionUsesLimitedRangeI420AndHandlesOddSizes() {
        val pixels = ByteBuffer.allocateDirect(3 * 3 * 4)
        repeat(9) { pixels.put(byteArrayOf(-1, 0, 0, -1)) }; pixels.rewind()
        val i420 = ProcessedVideoFrame("red", pixels, 3, 3, 10).toI420()
        assertEquals(17, i420.capacity())
        repeat(9) { assertEquals(82, i420.get(it).toInt() and 255) }
        repeat(4) {
            assertEquals(90, i420.get(9 + it).toInt() and 255)
            assertEquals(240, i420.get(13 + it).toInt() and 255)
        }
    }

    @Test fun confidentPersonRemainsSharpAndExpansionStaysLocal() {
        val confidence = FloatArray(25)
        confidence[12] = 0.95f
        val alpha = PersonConfidenceMatte.refine(confidence, 5, 5)
        assertEquals(1f, alpha[12])
        assertTrue(alpha[11] > 0.95f)
        assertTrue(alpha[6] > 0f)
        assertEquals(0f, alpha[0])
        assertEquals(0f, alpha[10])
    }

    @Test fun backgroundAndUnusableConfidenceNeverRevealForeground() {
        val alpha = PersonConfidenceMatte.refine(floatArrayOf(0f, Float.NaN, -1f, 0.05f), 2, 2)
        assertTrue(alpha.all { it == 0f })
        assertFalse(alpha.any { it.isNaN() })
    }

    @Test fun aSourceWithoutSubscribersIsNotWorthCopying() {
        val id = "unsubscribed-source"
        try {
            // During the Pre-Join preview nothing consumes the frames, so the
            // source must be able to skip the per-frame pixel copy.
            assertFalse(ProcessedVideoFrameHub.hasSubscribers(id))

            val sink = ProcessedVideoFrameSink { }
            ProcessedVideoFrameHub.register(id, sink)
            assertTrue(ProcessedVideoFrameHub.hasSubscribers(id))

            ProcessedVideoFrameHub.unregister(id, sink)
            assertFalse(ProcessedVideoFrameHub.hasSubscribers(id))
        } finally {
            ProcessedVideoFrameHub.clear(id)
        }
    }

    @Test fun aFailedSourceIsNotReportedAsSubscribed() {
        val id = "failed-subscribable-source"
        try {
            ProcessedVideoFrameHub.registerSourceErrorHandler(id) { }
            ProcessedVideoFrameHub.register(id, ProcessedVideoFrameSink { })
            assertTrue(ProcessedVideoFrameHub.hasSubscribers(id))

            ProcessedVideoFrameHub.reportSourceFailure(id, IllegalStateException("boom"))
            // A failed source stops publishing, so it must not advertise itself
            // as needing a pixel copy either.
            assertFalse(ProcessedVideoFrameHub.hasSubscribers(id))
        } finally {
            ProcessedVideoFrameHub.clear(id)
        }
    }
}
