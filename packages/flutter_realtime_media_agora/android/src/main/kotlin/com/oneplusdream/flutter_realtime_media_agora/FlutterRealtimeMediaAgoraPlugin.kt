package com.oneplusdream.flutter_realtime_media_agora
import com.oneplusdream.flutter_realtime_processed_video.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import java.nio.ByteBuffer

internal interface NativeProviderSink : ProcessedVideoFrameSink { fun dispose() }
internal object AgoraFramePusher {
    init { System.loadLibrary("realtime_frame_push") }
    external fun create(engineHandle: Long): Long
    external fun push(media: Long, rgba: ByteBuffer, width: Int, height: Int, timestampNs: Long, rotationDegrees: Int, trackId: Int): Int
    external fun release(media: Long)
}
internal class AgoraProcessedSink(sourceId: String, engine: Long, private val trackId: Int) : NativeProviderSink {
    private val sourceId = sourceId
    private var media = AgoraFramePusher.create(engine)
    init {
        require(media != 0L) { "Agora media engine is unavailable." }
        ProcessedVideoFrameHub.register(sourceId, this)
    }
    @Synchronized override fun onVideoFrame(frame: ProcessedVideoFrame) {
        if (media == 0L) return
        val result = AgoraFramePusher.push(media, frame.rgba, frame.width, frame.height, frame.timestampNs, frame.rotationDegrees, trackId)
        check(result == 0) { "Agora rejected processed frame: $result" }
    }
    @Synchronized override fun dispose() {
        ProcessedVideoFrameHub.unregister(sourceId, this)
        if (media != 0L) AgoraFramePusher.release(media)
        media = 0
    }
}

class FlutterRealtimeMediaAgoraPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val sinks = mutableMapOf<String, NativeProviderSink>()
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "flutter_realtime_media_agora/processed_video")
        channel.setMethodCallHandler(this)
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val key = call.argument<String>("bindingId").orEmpty()
        try {
            when (call.method) {
                "attachProvider" -> {
                    require(key.isNotEmpty()) { "Missing binding" }
                    sinks.remove(key)?.dispose()
                    val sourceId = call.argument<String>("sourceId").orEmpty()
                    sinks[key] = AgoraProcessedSink(sourceId, call.argument<Number>("engineHandle")!!.toLong(), call.argument<Number>("trackId")!!.toInt())
                    result.success(null)
                }
                "detachProvider" -> { sinks.remove(key)?.dispose(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) { result.error("processed_binding_failed", "processed.binding.${call.method}", null) }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        val failures = mutableListOf<Throwable>()
        sinks.values.forEach { try { it.dispose() } catch (error: Throwable) { failures.add(error) } }
        sinks.clear()
        if (failures.isNotEmpty()) android.util.Log.e("ProcessedVideo", "Processed sink release failed")
    }
}
