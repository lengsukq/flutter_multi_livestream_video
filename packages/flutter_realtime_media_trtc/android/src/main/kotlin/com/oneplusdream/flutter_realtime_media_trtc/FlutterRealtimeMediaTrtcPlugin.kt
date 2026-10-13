package com.oneplusdream.flutter_realtime_media_trtc
import com.oneplusdream.flutter_realtime_processed_video.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import java.nio.ByteBuffer
import com.tencent.trtc.TRTCCloud
import com.tencent.trtc.TRTCCloudDef

internal interface NativeProviderSink : ProcessedVideoFrameSink { fun dispose() }
internal class TrtcProcessedSink(context: Context, private val sourceId: String) : NativeProviderSink {
    private val cloud = TRTCCloud.sharedInstance(context)
    private var disposed = false
    init {
        cloud.stopLocalPreview()
        cloud.enableCustomVideoCapture(TRTCCloudDef.TRTC_VIDEO_STREAM_TYPE_BIG, true)
        ProcessedVideoFrameHub.register(sourceId, this)
    }
    @Synchronized override fun onVideoFrame(frame: ProcessedVideoFrame) {
        if (disposed) return
        val input = TRTCCloudDef.TRTCVideoFrame().apply {
            pixelFormat = TRTCCloudDef.TRTC_VIDEO_PIXEL_FORMAT_RGBA
            bufferType = TRTCCloudDef.TRTC_VIDEO_BUFFER_TYPE_BYTE_BUFFER
            buffer = frame.rgba; width = frame.width; height = frame.height
            timestamp = frame.timestampNs / 1_000_000; rotation = frame.rotationDegrees / 90
        }
        cloud.sendCustomVideoData(TRTCCloudDef.TRTC_VIDEO_STREAM_TYPE_BIG, input)
    }
    @Synchronized override fun dispose() {
        disposed = true
        ProcessedVideoFrameHub.unregister(sourceId, this)
        cloud.enableCustomVideoCapture(TRTCCloudDef.TRTC_VIDEO_STREAM_TYPE_BIG, false)
    }
}

class FlutterRealtimeMediaTrtcPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val sinks = mutableMapOf<String, NativeProviderSink>()
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "flutter_realtime_media_trtc/processed_video")
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
                    sinks[key] = TrtcProcessedSink(context, sourceId)
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
