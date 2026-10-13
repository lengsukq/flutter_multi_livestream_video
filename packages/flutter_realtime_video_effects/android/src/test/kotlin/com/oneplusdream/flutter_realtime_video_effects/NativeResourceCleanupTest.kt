package com.oneplusdream.flutter_realtime_video_effects

import org.junit.Assert.*
import org.junit.Test

class NativeResourceCleanupTest {
    @Test fun oneFailureDoesNotSkipTheOtherResourceOwners() {
        val stages = mutableListOf<String>()
        val cleanup = NativeResourceCleanup()
        val cause = IllegalStateException("internal native detail")
        cleanup.run("capture") { stages.add("capture"); throw cause }
        cleanup.run("processor") { stages.add("processor") }
        cleanup.run("preview") { stages.add("preview") }
        try { cleanup.finish(); fail("cleanup failure must reach the caller") }
        catch (error: IllegalStateException) {
            assertEquals(listOf("capture", "processor", "preview"), stages)
            assertEquals("native.cleanup.capture", error.message)
            assertSame(cause, error.suppressed.single())
        }
    }
    @Test fun rollbackPreservesThePrimaryFailureAndAddsCleanupDiagnostics() {
        val primary = IllegalArgumentException("native source initialization")
        val cleanup = NativeResourceCleanup()
        cleanup.run("preview") { throw IllegalStateException("surface release") }
        try { cleanup.finish(primary); fail("must retain primary failure") }
        catch (error: IllegalArgumentException) {
            assertSame(primary, error)
            assertEquals("native.cleanup.preview", error.suppressed.single().message)
        }
    }
}
