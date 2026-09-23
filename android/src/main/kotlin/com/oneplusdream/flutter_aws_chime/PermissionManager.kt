package com.oneplusdream.flutter_aws_chime

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

class PermissionManager(
        private val context: Context,
        activity: Activity?
) {
    private var activity: Activity? = activity

    val VIDEO_PERMISSION_REQUEST_CODE = 1
    val VIDEO_PERMISSIONS = arrayOf(
            Manifest.permission.CAMERA
    )

    val AUDIO_PERMISSION_REQUEST_CODE = 2
    val AUDIO_PERMISSIONS = arrayOf(
            Manifest.permission.MODIFY_AUDIO_SETTINGS,
            Manifest.permission.RECORD_AUDIO,
    )

    var audioResult: MethodChannel.Result? = null
    var videoResult: MethodChannel.Result? = null

    fun updateActivity(activity: Activity?) {
        if (activity == null) cancelPendingRequests()
        this.activity = activity
    }

    fun manageAudioPermissions(result: MethodChannel.Result) {
        audioResult = result
        if (hasPermissionsAlready(AUDIO_PERMISSIONS)) {
            audioCallbackReceived()
        } else {
            val currentActivity = activity
            if (currentActivity == null) {
                complete(audioResult, "The Android activity is not attached.", "invalid_state")
                audioResult = null
                return
            }
            ActivityCompat.requestPermissions(
                    currentActivity,
                    AUDIO_PERMISSIONS,
                    AUDIO_PERMISSION_REQUEST_CODE
            )
        }
    }

    fun manageVideoPermissions(result: MethodChannel.Result) {
        videoResult = result
        if (hasPermissionsAlready(VIDEO_PERMISSIONS)) {
            videoCallbackReceived()
        } else {
            val currentActivity = activity
            if (currentActivity == null) {
                complete(videoResult, "The Android activity is not attached.", "invalid_state")
                videoResult = null
                return
            }
            ActivityCompat.requestPermissions(
                    currentActivity,
                    VIDEO_PERMISSIONS,
                    VIDEO_PERMISSION_REQUEST_CODE
            )
        }
    }

    /**
     * Called from [FlutterAwsChimePlugin.onRequestPermissionsResult] when the
     * system permission dialog closes. Completes the pending MethodChannel call
     * so Dart's join() doesn't wait forever.
     */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        return when (requestCode) {
            AUDIO_PERMISSION_REQUEST_CODE -> {
                audioCallbackReceived()
                true
            }
            VIDEO_PERMISSION_REQUEST_CODE -> {
                videoCallbackReceived()
                true
            }
            else -> false
        }
    }

    fun audioCallbackReceived() {
        if (hasPermissionsAlready(AUDIO_PERMISSIONS)) {
            complete(audioResult, Response.audio_auth_granted.msg)
        } else {
            complete(audioResult, Response.audio_auth_not_granted.msg, "permission_denied")
        }
        audioResult = null
    }

    fun videoCallbackReceived() {
        if (hasPermissionsAlready(VIDEO_PERMISSIONS)) {
            complete(videoResult, Response.video_auth_granted.msg)
        } else {
            complete(videoResult, Response.video_auth_not_granted.msg, "permission_denied")
        }
        videoResult = null
    }

    fun cancelPendingRequests() {
        complete(audioResult, "Permission request was cancelled.", "invalid_state")
        complete(videoResult, "Permission request was cancelled.", "invalid_state")
        audioResult = null
        videoResult = null
    }

    private fun complete(result: MethodChannel.Result?, message: String, code: String? = null) {
        result?.success(
                MethodChannelResult(code == null, message, code).toFlutterCompatibleType()
        )
    }

    private fun hasPermissionsAlready(PERMISSIONS: Array<String>): Boolean {
        return PERMISSIONS.all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }
    }
}
