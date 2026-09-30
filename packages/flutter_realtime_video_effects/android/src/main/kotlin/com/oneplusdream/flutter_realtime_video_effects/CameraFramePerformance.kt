package com.oneplusdream.flutter_realtime_video_effects

/** Debug-only stage timings; no images or participant data are recorded. */
internal class CameraFramePerformance(private val enabled: Boolean) {
    private var mode = ""
    private var startNs = 0L
    private var inputs = 0
    private var outputs = 0
    private val stages = mutableMapOf<String, Long>()
    fun startFrame(effect: String) {
        if (!enabled) return
        if (mode != effect || startNs == 0L) {
            mode = effect; startNs = System.nanoTime(); inputs = 0; outputs = 0; stages.clear()
        }
        inputs++
    }
    fun stage(name: String, elapsedNs: Long) {
        if (enabled) stages[name] = (stages[name] ?: 0L) + elapsedNs
    }
    fun endFrame(presented: Boolean) {
        if (!enabled) return
        if (presented) outputs++
        val seconds = (System.nanoTime() - startNs) / 1_000_000_000.0
        if (seconds < 5.0) return
        fun average(name: String) = (stages[name] ?: 0L) / 1_000_000.0 / outputs.coerceAtLeast(1)
        android.util.Log.i("VideoEffectsPerf", String.format(java.util.Locale.US,
            "mode=%s input=%.1ffps preview=%.1ffps copy=%.1fms segment=%.1fms gpu=%.1fms draw=%.1fms",
            mode, inputs / seconds, outputs / seconds, average("copy"), average("segment"), average("gpu"), average("draw")))
        startNs = 0L
    }
}
