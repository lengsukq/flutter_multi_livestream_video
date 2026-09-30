package com.oneplusdream.flutter_realtime_video_effects

/** Refines only the outer confidence transition, keeping the person fully sharp. */
internal object PersonConfidenceMatte {
    /**
     * Confidence masks correspond to model labels when there are multiple
     * channels (background at 0, person at 1). The bundled selfie model exposes
     * only its foreground confidence mask, at index 0.
     */
    fun foregroundConfidenceMaskIndex(maskCount: Int): Int? = when {
        maskCount <= 0 -> null
        maskCount == 1 -> 0
        else -> 1
    }

    fun refine(confidence: FloatArray, width: Int, height: Int): FloatArray {
        require(width > 0 && height > 0 && confidence.size == width * height)
        val alpha = FloatArray(confidence.size)
        for (y in 0 until height) for (x in 0 until width) {
            val index = y * width + x
            var value = confidence[index].finiteConfidence()
            // At most one model pixel of weighted expansion protects thin hair and
            // shoulders. It does not blur the mask into the person's interior.
            for (dy in -1..1) for (dx in -1..1) {
                if (dx == 0 && dy == 0) continue
                val nx = x + dx
                val ny = y + dy
                if (nx !in 0 until width || ny !in 0 until height) continue
                val weight = if (dx != 0 && dy != 0) 0.55f else 0.7f
                value = maxOf(value, confidence[ny * width + nx].finiteConfidence() * weight)
            }
            val t = ((value - 0.1f) / 0.45f).coerceIn(0f, 1f)
            alpha[index] = t * t * (3f - 2f * t)
        }
        return alpha
    }

    private fun Float.finiteConfidence(): Float = if (isFinite()) coerceIn(0f, 1f) else 0f
}
