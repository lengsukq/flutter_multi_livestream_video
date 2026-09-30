package com.oneplusdream.flutter_realtime_video_effects

import java.nio.ByteBuffer
import java.nio.ByteOrder

/** Native GL writes do not advance ByteBuffer.position(), unlike Java put(). */
internal object RgbaReadback {
    fun topDown(source: ByteBuffer, width: Int, height: Int, reusable: ByteBuffer? = null): ByteBuffer {
        require(width > 0 && height > 0)
        val rowBytes = width * 4
        val total = rowBytes * height
        require(source.capacity() >= total)
        val input = source.duplicate().apply { clear(); limit(total) }
        val out = reusable?.takeIf { it.capacity() >= total }
            ?: ByteBuffer.allocateDirect(total).order(ByteOrder.nativeOrder())
        out.clear()
        val row = ByteArray(rowBytes)
        for (y in height - 1 downTo 0) {
            input.position(y * rowBytes)
            input.get(row)
            out.put(row)
        }
        out.flip()
        return out
    }
}
