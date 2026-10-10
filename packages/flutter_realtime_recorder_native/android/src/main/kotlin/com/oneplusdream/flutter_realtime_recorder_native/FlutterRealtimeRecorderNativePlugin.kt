package com.oneplusdream.flutter_realtime_recorder_native

import android.app.Activity
import android.app.Activity.RESULT_OK
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import java.io.File
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.PluginRegistry

/** MediaProjection requires an explicit, fresh system user-consent dialog on
 * each start. We do not attempt to capture vendor streams or bypass consent.
 */
class FlutterRealtimeRecorderNativePlugin :
    FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler,
    PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var context: Context
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingStart: MethodChannel.Result? = null
    private var pendingExport: MethodChannel.Result? = null
    private var exportSource: File? = null
    private var pendingRoomCode = "room"
    private val requestCode = 0x4A39
    private val exportRequestCode = 0x4A3A

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "flutter_realtime_recorder_native")
        channel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "flutter_realtime_recorder_native/events")
        eventChannel.setStreamHandler(this)
        RecorderProjectionService.onInterrupted = { room, reason ->
            Handler(Looper.getMainLooper()).post {
                eventSink?.success(mapOf("roomCode" to room, "reason" to reason))
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        RecorderProjectionService.onInterrupted = null
        pendingStart?.error("cancelled", "Recording plugin detached during capture consent.", null)
        pendingStart = null
        pendingExport?.error("cancelled", "Recording plugin detached during file export.", null)
        pendingExport = null
        exportSource = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }
    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
        pendingStart?.error("cancelled", "Activity closed before screen capture permission.", null)
        pendingStart = null
        pendingExport?.error("cancelled", "Activity closed before file export.", null)
        pendingExport = null
        exportSource = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val current = activity
                if (current == null) {
                    result.error("invalidState", "Recording requires an Android Activity.", null)
                    return
                }
                if (pendingStart != null || RecorderProjectionService.active != null) {
                    result.error("invalidState", "A recording is already starting or running.", null)
                    return
                }
                val manager = current.getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                    as MediaProjectionManager
                pendingRoomCode = call.argument<String>("roomCode") ?: "room"
                pendingStart = result
                try {
                    current.startActivityForResult(manager.createScreenCaptureIntent(), requestCode)
                } catch (error: Exception) {
                    pendingStart = null
                    result.error("startFailed", error.message, null)
                }
            }
            "stop" -> {
                val recorder = RecorderProjectionService.active
                if (recorder == null) {
                    result.error("invalidState", "No active recording.", null)
                    return
                }
                try {
                    result.success(recorder.stopRecording())
                } catch (error: Exception) {
                    result.error("stopFailed", error.message, null)
                }
            }
            "export" -> {
                val current = activity
                if (current == null || pendingExport != null) {
                    result.error("invalidState", "File export requires an available Activity.", null)
                    return
                }
                try {
                    val source = validatedRecording(call.argument<String>("localFilePath"))
                    exportSource = source
                    pendingExport = result
                    val chooseFile = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("video/mp4")
                        .putExtra(Intent.EXTRA_TITLE, source.name)
                    current.startActivityForResult(chooseFile, exportRequestCode)
                } catch (error: Exception) {
                    exportSource = null
                    pendingExport = null
                    result.error("exportFailed", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(code: Int, resultCode: Int, data: Intent?): Boolean {
        if (code == exportRequestCode) {
            val completion = pendingExport ?: return true
            val source = exportSource
            pendingExport = null
            exportSource = null
            if (resultCode != RESULT_OK || data?.data == null || source == null) {
                completion.error("cancelled", "The recording export was cancelled.", null)
                return true
            }
            val uri = requireNotNull(data.data)
            Thread {
                val outcome = runCatching {
                    // Validate again after the picker returns; a path may have
                    // been deleted while the user was choosing a destination.
                    val file = validatedRecording(source.absolutePath)
                    val stream = context.contentResolver.openOutputStream(uri, "w")
                        ?: throw IllegalStateException("Could not open export destination.")
                    stream.use { output ->
                        file.inputStream().use { input -> input.copyTo(output) }
                    }
                    uri.toString()
                }
                Handler(Looper.getMainLooper()).post {
                    outcome.fold(
                        onSuccess = { completion.success(it) },
                        onFailure = { completion.error("exportFailed", it.message, null) }
                    )
                }
            }.start()
            return true
        }
        if (code != requestCode) return false
        val completion = pendingStart ?: return true
        pendingStart = null
        if (resultCode != RESULT_OK || data == null) {
            completion.error("permissionDenied", "Screen recording was not authorized.", null)
            return true
        }
        RecorderProjectionService.start(
            context, resultCode, data, pendingRoomCode
        ) { outcome ->
            outcome.fold(
                onSuccess = { completion.success(it) },
                onFailure = { completion.error("startFailed", it.message, null) }
            )
        }
        return true
    }

    private fun validatedRecording(path: String?): File {
        require(!path.isNullOrBlank()) { "Missing recording file path." }
        val dir = File(context.filesDir, "realtime_recordings").canonicalFile
        val source = File(path).canonicalFile
        require(source.parentFile == dir && source.extension.equals("mp4", true)) {
            "Only finalized app-owned MP4 recordings can be exported."
        }
        require(source.isFile && source.canRead() && source.length() > 0) {
            "The recording is missing or empty."
        }
        return source
    }
}
