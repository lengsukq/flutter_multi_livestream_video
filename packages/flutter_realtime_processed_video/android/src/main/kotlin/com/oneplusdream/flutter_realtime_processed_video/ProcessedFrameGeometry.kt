package com.oneplusdream.flutter_realtime_processed_video

/** Geometry for a top-down sensor RGBA frame rendered upright to an EGL surface. */
object ProcessedFrameGeometry {
    @JvmStatic fun outputWidth(width: Int, height: Int, rotationDegrees: Int): Int =
        if (quarterTurn(rotationDegrees)) height else width

    @JvmStatic fun outputHeight(width: Int, height: Int, rotationDegrees: Int): Int =
        if (quarterTurn(rotationDegrees)) width else height

    // Inverse of the clockwise sensor-to-upright rotation, in triangle-strip order:
    // bottom-left, bottom-right, top-left, top-right. Also accounts for EGL's Y axis.
    @JvmStatic fun textureCoordinates(rotationDegrees: Int): FloatArray = when (rotationDegrees) {
        0 -> floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f)
        90 -> floatArrayOf(1f, 1f, 1f, 0f, 0f, 1f, 0f, 0f)
        180 -> floatArrayOf(1f, 0f, 0f, 0f, 1f, 1f, 0f, 1f)
        270 -> floatArrayOf(0f, 0f, 0f, 1f, 1f, 0f, 1f, 1f)
        else -> throw IllegalArgumentException("Unsupported frame rotation: $rotationDegrees")
    }

    private fun quarterTurn(rotation: Int): Boolean {
        require(rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270)
        return rotation == 90 || rotation == 270
    }
}
