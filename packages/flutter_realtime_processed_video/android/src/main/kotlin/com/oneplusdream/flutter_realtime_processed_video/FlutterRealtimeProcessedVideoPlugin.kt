package com.oneplusdream.flutter_realtime_processed_video
import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FlutterRealtimeProcessedVideoPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "flutter_realtime_processed_video/sources")
        channel.setMethodCallHandler(this)
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val id = call.argument<String>("sourceId").orEmpty()
            when (call.method) {
                "setEnabled" -> { ProcessedVideoSourceControls.setEnabled(id, call.argument<Boolean>("enabled") == true); result.success(null) }
                "selectCamera" -> { ProcessedVideoSourceControls.selectCamera(id, call.argument<String>("deviceId")); result.success(null) }
                "listCameras" -> {
                    val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                    val directions = manager.cameraIdList.map { manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) }.toSet()
                    result.success(listOfNotNull(
                        if (directions.contains(CameraCharacteristics.LENS_FACING_FRONT)) mapOf("id" to "front", "label" to "Front camera", "isFrontFacing" to true) else null,
                        if (directions.contains(CameraCharacteristics.LENS_FACING_BACK)) mapOf("id" to "back", "label" to "Back camera", "isFrontFacing" to false) else null,
                    ))
                }
                else -> result.notImplemented()
            }
        } catch (error: Throwable) { result.error("processed_source_failed", "processed.source.${call.method}", null) }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { channel.setMethodCallHandler(null) }
}
