package com.oneplusdream.flutter_realtime_video_effects

import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArraySet

data class ProcessedVideoFrame(
    val sourceId: String,
    val rgba: ByteBuffer,
    val width: Int,
    val height: Int,
    val timestampNs: Long,
    val rotationDegrees: Int = 0,
    val pixelFormat: String = "rgba8888",
    val rowStride: Int = width * 4,
    val mirrored: Boolean = false,
 ) {
    fun toI420(): ByteBuffer {
        val chromaWidth = (width + 1) / 2
        val chromaHeight = (height + 1) / 2
        val ySize = width * height
        val cSize = chromaWidth * chromaHeight
        val result = ByteBuffer.allocateDirect(ySize + cSize * 2)
        fun channel(x: Int, y: Int, c: Int) = rgba.get(y * rowStride + x * 4 + c).toInt() and 255
        for (y in 0 until height) for (x in 0 until width) {
            val r = channel(x,y,0); val g = channel(x,y,1); val b = channel(x,y,2)
            result.put(y * width + x, (((66*r + 129*g + 25*b + 128) shr 8) + 16).coerceIn(0,255).toByte())
        }
        for (y in 0 until chromaHeight) for (x in 0 until chromaWidth) {
            var r = 0; var g = 0; var b = 0; var count = 0
            for (dy in 0..1) for (dx in 0..1) {
                val px = x*2+dx; val py = y*2+dy
                if (px < width && py < height) { r += channel(px,py,0); g += channel(px,py,1); b += channel(px,py,2); count++ }
            }
            r /= count; g /= count; b /= count
            val index = y * chromaWidth + x
            result.put(ySize + index, (((-38*r - 74*g + 112*b + 128) shr 8) + 128).coerceIn(0,255).toByte())
            result.put(ySize + cSize + index, (((112*r - 94*g - 18*b + 128) shr 8) + 128).coerceIn(0,255).toByte())
        }
        return result
    }
}

fun interface ProcessedVideoFrameSink {
    fun onVideoFrame(frame: ProcessedVideoFrame)
}

/**
 * Native-only frame fan-out. Provider plugins subscribe with [sourceId].
 *
 * Frame bytes never cross MethodChannel. Each sink receives a read-only view
 * of the same direct RGBA buffer for the current frame.
 */
object ProcessedVideoFrameHub {
    private val sinks =
        ConcurrentHashMap<String, CopyOnWriteArraySet<ProcessedVideoFrameSink>>()
    private val sourceErrorHandlers = ConcurrentHashMap<String, (Throwable) -> Unit>()
    private val failedSources = ConcurrentHashMap.newKeySet<String>()

    fun register(sourceId: String, sink: ProcessedVideoFrameSink) {
        sinks.getOrPut(sourceId) { CopyOnWriteArraySet() }.add(sink)
    }

    fun unregister(sourceId: String, sink: ProcessedVideoFrameSink) {
        sinks[sourceId]?.let { current ->
            current.remove(sink)
            if (current.isEmpty()) sinks.remove(sourceId, current)
        }
    }

    fun registerSourceErrorHandler(sourceId: String, handler: (Throwable) -> Unit) {
        sourceErrorHandlers[sourceId] = handler
        failedSources.remove(sourceId)
    }

    fun unregisterSourceErrorHandler(sourceId: String, handler: (Throwable) -> Unit) {
        sourceErrorHandlers.remove(sourceId, handler)
        failedSources.remove(sourceId)
    }

    /** Reports one failure per source until that source explicitly recovers. */
    fun reportSourceFailure(sourceId: String, error: Throwable) {
        if (!failedSources.add(sourceId)) return
        val handler = sourceErrorHandlers[sourceId]
        if (handler == null) {
            android.util.Log.e("VideoEffects", "Processed video source failed: $sourceId", error)
            return
        }
        try {
            handler(error)
        } catch (handlerError: Throwable) {
            android.util.Log.e("VideoEffects", "Processed video failure handler failed: $sourceId", handlerError)
        }
    }

    fun resetSourceFailure(sourceId: String) {
        failedSources.remove(sourceId)
    }

    fun clear(sourceId: String) {
        sinks.remove(sourceId)
        sourceErrorHandlers.remove(sourceId)
        failedSources.remove(sourceId)
    }

    fun publish(frame: ProcessedVideoFrame) {
        if (failedSources.contains(frame.sourceId)) return
        val current = sinks[frame.sourceId] ?: return
        for (sink in current) {
            val view = frame.rgba.asReadOnlyBuffer()
            view.rewind()
            try {
                sink.onVideoFrame(frame.copy(rgba = view))
            } catch (error: Throwable) {
                reportSourceFailure(frame.sourceId, error)
                break
            }
        }
    }

    /**
     * Whether anything is listening for [sourceId]'s frames. A source must not
     * pay for the per-frame pixel copy when nobody consumes it: during the
     * Pre-Join preview no provider sink is attached yet, and copying a
     * full-resolution frame there is pure waste.
     */
    fun hasSubscribers(sourceId: String): Boolean =
        !failedSources.contains(sourceId) && sinks[sourceId]?.isNotEmpty() == true
}
