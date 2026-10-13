package com.oneplusdream.flutter_realtime_video_effects

/** Attempts every independent teardown step and retains their stage/cause. */
internal class NativeResourceCleanup {
    private val failures = mutableListOf<Pair<String, Throwable>>()
    fun run(stage: String, release: () -> Unit) {
        try { release() } catch (error: Throwable) { failures.add(stage to error) }
    }
    fun finish(primary: Throwable? = null) {
        if (failures.isEmpty()) return
        val failure = IllegalStateException("native.cleanup.${failures.joinToString(",") { it.first }}")
        failures.forEach { (_, cause) -> failure.addSuppressed(cause) }
        if (primary != null) { primary.addSuppressed(failure); throw primary }
        throw failure
    }
}
