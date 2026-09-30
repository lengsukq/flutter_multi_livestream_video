package com.oneplusdream.flutter_realtime_video_effects

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class FlutterRealtimeVideoEffectsPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var textureRegistry: TextureRegistry
    private lateinit var applicationContext: android.content.Context
    private var lifecycleOwner: LifecycleOwner? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private val cameraPermissionRequests = CameraPermissionRequestQueue()
    private val permissionListener = PluginRegistry.RequestPermissionsResultListener { requestCode, permissions, grantResults ->
        val granted = permissions.indices.any { index ->
            permissions[index] == Manifest.permission.CAMERA && grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
        }
        cameraPermissionRequests.onPermissionResult(requestCode, granted)
    }
    private val providerSinks = ConcurrentHashMap<String, NativeProviderSink>()
    private val providerSinkSources = ConcurrentHashMap<String, String>()
    private val sources = ConcurrentHashMap<String, AndroidVideoEffectsSource>()
    private val pendingSourceStarts = ConcurrentHashMap<String, OnceMethodResult>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        textureRegistry = binding.textureRegistry
        channel = MethodChannel(
            binding.binaryMessenger,
            "flutter_realtime_video_effects",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(lifecycleOwner != null)
            "createSource" -> createSource(call, result)
            "attachProvider" -> {
                try {
                    val sourceId = call.argument<String>("sourceId").orEmpty()
                    require(sources.containsKey(sourceId)) { "Unknown video source: $sourceId" }
                    val key = call.argument<String>("bindingId").orEmpty()
                    removeProviderSink(key)
                    val sink = when (call.argument<String>("providerId")) {
                        "agora" -> AgoraProcessedSink(sourceId,
                            call.argument<Number>("engineHandle")!!.toLong(), call.argument<Number>("trackId")!!.toInt())
                        "trtc" -> TrtcProcessedSink(applicationContext, sourceId)
                        else -> error("Unsupported processed video provider.")
                    }
                    providerSinkSources[key] = sourceId
                    providerSinks[key] = sink
                    result.success(null)
                } catch (error: Throwable) { result.error("attach_provider_failed", error.message, null) }
            }
            "detachProvider" -> {
                removeProviderSink(call.argument<String>("bindingId").orEmpty())
                result.success(null)
            }
            "setEffect" -> sourceCall(call, result) { source, args ->
                val effect = args["effect"] as? Map<*, *> ?: emptyMap<String, Any?>()
                source.setEffect(
                    effect["type"]?.toString() ?: "none",
                    effect["blurStrength"]?.toString() ?: "medium",
                    effectBytes(effect["imageBytes"]),
                )
            }
            "setEnabled" -> sourceCall(call, result) { source, args ->
                source.setEnabled(args["enabled"] as? Boolean ?: false)
            }
            "selectCamera" -> sourceCall(call, result) { source, args ->
                source.selectCamera(args["deviceId"]?.toString())
            }
            "listCameras" -> {
                val future = androidx.camera.lifecycle.ProcessCameraProvider.getInstance(applicationContext)
                future.addListener({
                    try {
                        val provider = future.get()
                        val cameras = mutableListOf<Map<String, Any>>()
                        if (provider.hasCamera(androidx.camera.core.CameraSelector.DEFAULT_FRONT_CAMERA)) {
                            cameras.add(mapOf("id" to "front", "label" to "Front camera", "isFrontFacing" to true))
                        }
                        if (provider.hasCamera(androidx.camera.core.CameraSelector.DEFAULT_BACK_CAMERA)) {
                            cameras.add(mapOf("id" to "back", "label" to "Back camera", "isFrontFacing" to false))
                        }
                        result.success(cameras)
                    } catch (error: Throwable) { result.error("camera_enumeration_failed", error.message, null) }
                }, androidx.core.content.ContextCompat.getMainExecutor(applicationContext))
            }
            "disposeSource" -> {
                val sourceId = call.argument<String>("sourceId").orEmpty()
                removeProviderSinksForSource(sourceId)
                pendingSourceStarts.remove(sourceId)?.error(
                    "source_creation_cancelled",
                    "Video source creation was cancelled before the source started.",
                    null,
                )
                sources.remove(sourceId)?.let { source ->
                    try {
                        source.dispose()
                    } catch (error: Throwable) {
                        result.error("dispose_source_failed", error.message, null)
                        return
                    }
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun createSource(call: MethodCall, result: MethodChannel.Result) {
        val guardedResult = OnceMethodResult(result)
        val owner = lifecycleOwner
        val currentActivity = activity
        if (owner == null || currentActivity == null) {
            guardedResult.error(
                "activity_unavailable",
                "Video effects require an attached LifecycleOwner.",
                null,
            )
            return
        }
        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
        if (ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            createSourceNowSafely(args, guardedResult)
            return
        }
        cameraPermissionRequests.request(
            hasPermission = false,
            requestPermission = { requestCode ->
                ActivityCompat.requestPermissions(currentActivity, arrayOf(Manifest.permission.CAMERA), requestCode)
            },
            onGranted = { createSourceNowSafely(args, guardedResult) },
            onDenied = { failure -> guardedResult.error(failure.code, failure.message, null) },
        )
    }

    private fun createSourceNowSafely(args: Map<String, Any?>, result: OnceMethodResult) {
        try {
            createSourceNow(args, result)
        } catch (error: Throwable) {
            result.error("create_source_failed", error.message, null)
        }
    }

    private fun createSourceNow(args: Map<String, Any?>, result: OnceMethodResult) {
        val owner = lifecycleOwner
        if (owner == null || activity == null) {
            result.error("activity_unavailable", "Video effects require an attached LifecycleOwner.", null)
            return
        }
        @Suppress("UNCHECKED_CAST")
        val effect = args["effect"] as? Map<String, Any?> ?: emptyMap()
        val sourceId = UUID.randomUUID().toString()
        // `createSurfaceTexture` gives a `SurfaceTexture` whose size can be set
        // synchronously. Canvas owns preview throughout; GPU effects use an
        // independent offscreen surface so mode changes never switch producers.
        val textureEntry = try {
            textureRegistry.createSurfaceTexture()
        } catch (error: Throwable) {
            result.error("create_source_failed", error.message, null)
            return
        }
        val source = try { AndroidVideoEffectsSource(
            context = applicationContext,
            lifecycleOwner = owner,
            sourceId = sourceId,
            width = (args["width"] as? Number)?.toInt() ?: 1280,
            height = (args["height"] as? Number)?.toInt() ?: 720,
            frameRate = (args["frameRate"] as? Number)?.toInt() ?: 24,
            cameraDeviceId = args["cameraDeviceId"]?.toString(),
            effectType = effect["type"]?.toString() ?: "none",
            blurStrength = effect["blurStrength"]?.toString() ?: "medium",
            backgroundImageBytes = effectBytes(effect["imageBytes"]),
            textureEntry = textureEntry,
            onFailure = { error -> android.os.Handler(android.os.Looper.getMainLooper()).post {
                if (sources.containsKey(sourceId)) {
                    channel.invokeMethod("sourceError", mapOf("sourceId" to sourceId, "message" to error.message))
                }
            } },
        ) } catch (error: Throwable) {
            textureEntry.release()
            result.error("create_source_failed", error.cause?.message ?: error.message, null)
            return
        }
        sources[sourceId] = source
        pendingSourceStarts[sourceId] = result
        try {
            source.start(
                onStarted = {
                    pendingSourceStarts.remove(sourceId)
                    result.success(
                        mapOf(
                            "id" to sourceId,
                            "platform" to "android",
                            "kind" to "nativeFrameHub",
                            "width" to source.outputWidth,
                            "height" to source.outputHeight,
                            "frameRate" to source.frameRate,
                            "previewTextureId" to textureEntry.id(),
                        ),
                    )
                },
                onError = { error ->
                    pendingSourceStarts.remove(sourceId)
                    sources.remove(sourceId)
                    disposeSourceSafely(source)
                    result.error("create_source_failed", error.message, null)
                },
            )
        } catch (error: Throwable) {
            pendingSourceStarts.remove(sourceId)
            sources.remove(sourceId)
            disposeSourceSafely(source)
            result.error("create_source_failed", error.message, null)
        }
    }

    private fun sourceCall(
        call: MethodCall,
        result: MethodChannel.Result,
        operation: (AndroidVideoEffectsSource, Map<String, Any?>) -> Unit,
    ) {
        @Suppress("UNCHECKED_CAST")
        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
        val sourceId = args["sourceId"]?.toString().orEmpty()
        val source = sources[sourceId]
        if (source == null) {
            result.error("source_not_found", "Unknown video source: $sourceId", null)
            return
        }
        try {
            operation(source, args)
            result.success(null)
        } catch (error: Throwable) {
            result.error("source_operation_failed", error.message, null)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        lifecycleOwner = binding.activity as? LifecycleOwner
        activityBinding = binding
        binding.addRequestPermissionsResultListener(permissionListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(permissionListener)
        activityBinding = null
        activity = null
        cameraPermissionRequests.cancelPending("Camera permission request was cancelled because the Activity detached.")
        cancelPendingSourceStarts("Video source creation was cancelled because the Activity detached.")
        disposeProviderSinks()
        disposeSources()
        lifecycleOwner = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        activityBinding?.removeRequestPermissionsResultListener(permissionListener)
        activityBinding = null
        activity = null
        lifecycleOwner = null
        cameraPermissionRequests.cancelPending("Camera permission request was cancelled because the Flutter engine detached.")
        cancelPendingSourceStarts("Video source creation was cancelled because the Flutter engine detached.")
        disposeProviderSinks()
        disposeSources()
        channel.setMethodCallHandler(null)
    }

    private fun effectBytes(value: Any?): ByteArray? = when (value) {
        is ByteArray -> value
        is List<*> -> ByteArray(value.size) { index ->
            ((value[index] as? Number)?.toInt() ?: 0).toByte()
        }
        else -> null
    }

    private fun removeProviderSink(bindingId: String) {
        providerSinkSources.remove(bindingId)
        providerSinks.remove(bindingId)?.let(::disposeProviderSinkSafely)
    }

    private fun removeProviderSinksForSource(sourceId: String) {
        providerSinkSources.entries
            .filter { it.value == sourceId }
            .forEach { (bindingId, ownerSourceId) ->
                if (providerSinkSources.remove(bindingId, ownerSourceId)) {
                    providerSinks.remove(bindingId)?.let(::disposeProviderSinkSafely)
                }
            }
    }

    private fun disposeProviderSinks() {
        val sinks = providerSinks.values.toList()
        providerSinks.clear()
        providerSinkSources.clear()
        sinks.forEach(::disposeProviderSinkSafely)
    }

    private fun disposeSources() {
        val activeSources = sources.values.toList()
        sources.clear()
        activeSources.forEach(::disposeSourceSafely)
    }

    private fun disposeSourceSafely(source: AndroidVideoEffectsSource) {
        try {
            source.dispose()
        } catch (error: Throwable) {
            android.util.Log.e("VideoEffects", "Failed to dispose processed video source.", error)
        }
    }

    private fun disposeProviderSinkSafely(sink: NativeProviderSink) {
        try {
            sink.dispose()
        } catch (error: Throwable) {
            android.util.Log.e("VideoEffects", "Failed to dispose provider frame sink.", error)
        }
    }

    private fun cancelPendingSourceStarts(message: String) {
        pendingSourceStarts.entries.toList().forEach { (sourceId, result) ->
            if (pendingSourceStarts.remove(sourceId, result)) {
                result.error("source_creation_cancelled", message, null)
            }
        }
    }

    private class OnceMethodResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
        private val completed = java.util.concurrent.atomic.AtomicBoolean(false)

        override fun success(result: Any?) {
            if (completed.compareAndSet(false, true)) delegate.success(result)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            if (completed.compareAndSet(false, true)) delegate.error(errorCode, errorMessage, errorDetails)
        }

        override fun notImplemented() {
            if (completed.compareAndSet(false, true)) delegate.notImplemented()
        }
    }

}
