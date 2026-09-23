package com.oneplusdream.flutter_aws_chime

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** FlutterAwsChimePlugin */
class FlutterAwsChimePlugin : FlutterPlugin, ActivityAware,
        PluginRegistry.RequestPermissionsResultListener {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var methodChannel: MethodChannelCoordinator
    private lateinit var binaryMessenger: BinaryMessenger
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {

        flutterPluginBinding.platformViewRegistry.registerViewFactory("videoTile", FlutterVideoTileFactory())
        binaryMessenger = flutterPluginBinding.binaryMessenger;

    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {


    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
        methodChannel = MethodChannelCoordinator(binaryMessenger, binding.activity);
        methodChannel?.setupMethodChannel()
    }

    override fun onRequestPermissionsResult(
            requestCode: Int,
            permissions: Array<out String>,
            grantResults: IntArray
    ): Boolean {
        // Route the system callback back to the pending permission request.
        // Without this, join() hangs forever waiting for camera/mic approval.
        if (::methodChannel.isInitialized) {
            methodChannel.permissionsManager.onRequestPermissionsResult(requestCode)
            return true
        }
        return false
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }


}
