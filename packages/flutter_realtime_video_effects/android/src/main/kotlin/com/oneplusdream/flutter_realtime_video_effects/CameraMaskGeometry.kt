package com.oneplusdream.flutter_realtime_video_effects

/** Maps a mask inferred from an upright image back to CameraX sensor pixels. */
internal object CameraMaskGeometry {
    data class SensorMask(val confidence: FloatArray, val width: Int, val height: Int)

    fun toSensor(confidence: FloatArray, width: Int, height: Int, rotationDegrees: Int): SensorMask {
        require(width > 0 && height > 0 && confidence.size == width * height)
        val rotation = ((rotationDegrees % 360) + 360) % 360
        require(rotation % 90 == 0)
        if (rotation == 0) return SensorMask(confidence, width, height)
        val sensorWidth = if (rotation == 180) width else height
        val sensorHeight = if (rotation == 180) height else width
        val sensor = FloatArray(confidence.size)
        for (y in 0 until sensorHeight) for (x in 0 until sensorWidth) {
            val uprightX: Int
            val uprightY: Int
            when (rotation) {
                90 -> { uprightX = sensorHeight - 1 - y; uprightY = x }
                180 -> { uprightX = sensorWidth - 1 - x; uprightY = sensorHeight - 1 - y }
                else -> { uprightX = y; uprightY = sensorWidth - 1 - x }
            }
            sensor[y * sensorWidth + x] = confidence[uprightY * width + uprightX]
        }
        return SensorMask(sensor, sensorWidth, sensorHeight)
    }
}
