package com.oneplusdream.flutter_realtime_video_effects

import org.junit.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class CameraMaskGeometryTest {
    // Sensor pixels: [1 2 3; 4 5 6]. Upright masks must return to that grid.
    private val sensor = floatArrayOf(1f, 2f, 3f, 4f, 5f, 6f)

    @Test fun portraitFrontCameraMaskReturnsToTheSensorGrid() {
        val result = CameraMaskGeometry.toSensor(floatArrayOf(3f, 6f, 2f, 5f, 1f, 4f), 2, 3, 270)
        assertContentEquals(sensor, result.confidence)
        assertEquals(3, result.width)
        assertEquals(2, result.height)
    }
    @Test fun portraitBackCameraMaskReturnsToTheSensorGrid() {
        val result = CameraMaskGeometry.toSensor(floatArrayOf(4f, 1f, 5f, 2f, 6f, 3f), 2, 3, 90)
        assertContentEquals(sensor, result.confidence)
        assertEquals(3, result.width)
        assertEquals(2, result.height)
    }
    @Test fun upsideDownMaskReturnsToTheSensorGrid() {
        val result = CameraMaskGeometry.toSensor(sensor.reversedArray(), 3, 2, 180)
        assertContentEquals(sensor, result.confidence)
    }
    @Test fun landscapeMaskNeedsNoRotation() {
        assertContentEquals(sensor, CameraMaskGeometry.toSensor(sensor, 3, 2, 0).confidence)
    }
    @Test fun nonRightAngleRotationIsRejected() {
        assertFailsWith<IllegalArgumentException> { CameraMaskGeometry.toSensor(sensor, 3, 2, 45) }
    }
}
