package com.oneplusdream.flutter_realtime_recorder_native

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaMetadataRetriever
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.util.Log
import java.io.File
import java.util.UUID

/**
 * A screen/video-only recorder. Android does not guarantee RTC playback/system
 * audio capture across vendors, so this V1 NEVER advertises hasAudio=true.
 *
 * A foreground service must be running before getMediaProjection (Android 14).
 */
class RecorderProjectionService : Service() {
    companion object {
        @Volatile var active: RecorderProjectionService? = null
            private set
        @Volatile var onInterrupted: ((String, String) -> Unit)? = null
        private var callback: ((Result<Map<String, Any>>) -> Unit)? = null
        private const val CHANNEL_ID = "flutter_realtime_screen_recording"
        private const val NOTIFICATION_ID = 6131

        fun start(
            context: Context, code: Int, data: Intent, roomCode: String,
            completion: (Result<Map<String, Any>>) -> Unit
        ) {
            if (callback != null || active != null) {
                completion(Result.failure(IllegalStateException("Recorder already active.")))
                return
            }
            callback = completion
            val intent = Intent(context, RecorderProjectionService::class.java)
                .putExtra("resultCode", code)
                .putExtra("resultData", data)
                .putExtra("roomCode", roomCode)
            try {
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
            } catch (error: Exception) {
                callback = null
                completion(Result.failure(error))
            }
        }

        private fun finishStart(result: Result<Map<String, Any>>) {
            val done = callback
            callback = null
            done?.invoke(result)
        }
    }

    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var encoder: MediaRecorder? = null
    private var output: File? = null
    private var startedAtMs: Long = 0
    private var currentRoomCode: String = ""
    private var stopping = false
    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            if (!stopping) {
                // Consent was revoked while capturing. There is no valid
                // finalized artifact to report as a successful recording.
                cleanup(removeFile = true)
                onInterrupted?.invoke(
                    currentRoomCode,
                    "Screen recording permission or system capture was stopped."
                )
                stopSelf()
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        var stage = "foreground service"
        try {
            beginForeground()
            stage = "media projection permission token"
            val consent = intent?.parcelableResultData()
                ?: throw IllegalStateException("Missing MediaProjection consent token.")
            val code = intent.getIntExtra("resultCode", 0)
            val roomCode = intent.getStringExtra("roomCode") ?: "room"
            currentRoomCode = roomCode
            val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                as MediaProjectionManager
            stage = "MediaProjectionManager.getMediaProjection"
            val grantedProjection = manager.getMediaProjection(code, consent)
                ?: throw IllegalStateException("MediaProjection authorization failed.")
            projection = grantedProjection
            grantedProjection.registerCallback(projectionCallback, null)

            val metrics = DisplayMetrics().also {
                @Suppress("DEPRECATION")
                (getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager)
                    .defaultDisplay.getRealMetrics(it)
            }
            val factor = minOf(1.0, 1920.0 / maxOf(metrics.widthPixels, metrics.heightPixels))
            val width = ((metrics.widthPixels * factor).toInt() / 2) * 2
            val height = ((metrics.heightPixels * factor).toInt() / 2) * 2
            val folder = File(filesDir, "realtime_recordings")
            check(folder.exists() || folder.mkdirs()) { "Cannot create recording directory." }
            val safeRoom = roomCode.replace(Regex("[^a-zA-Z0-9_-]"), "_").take(60)
            val file = File(folder, "${safeRoom}-${UUID.randomUUID()}.mp4")
            output = file
            stage = "H264 MediaRecorder prepare"
            val mediaRecorder =
                if (Build.VERSION.SDK_INT >= 31) MediaRecorder(this) else {
                    @Suppress("DEPRECATION")
                    MediaRecorder()
                }
            encoder = mediaRecorder
            mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE)
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            mediaRecorder.setVideoSize(width, height)
            mediaRecorder.setVideoFrameRate(30)
            mediaRecorder.setVideoEncodingBitRate(5_000_000)
            mediaRecorder.setOutputFile(file.absolutePath)
            mediaRecorder.prepare()
            stage = "MediaProjection.createVirtualDisplay"
            virtualDisplay = grantedProjection.createVirtualDisplay(
                "Flutter Realtime Recording", width, height, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                mediaRecorder.surface, null, null
            )
            stage = "MediaRecorder.start"
            mediaRecorder.start()
            startedAtMs = android.os.SystemClock.elapsedRealtime()
            active = this
            finishStart(Result.success(mapOf(
                "localFilePath" to file.absolutePath,
                "fileName" to file.name
            )))
        } catch (error: Exception) {
            Log.e("FlutterRealtimeRecorder", "Recording failed at $stage", error)
            cleanup(removeFile = true)
            finishStart(Result.failure(IllegalStateException(
                "Android recording could not start at [$stage]: ${error.message ?: error.javaClass.simpleName}",
                error
            )))
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun beginForeground() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL_ID, "Meeting recording", NotificationManager.IMPORTANCE_LOW
            ))
        }
        val builder =
            if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID)
            else @Suppress("DEPRECATION") Notification.Builder(this)
        val notification = builder
            .setContentTitle("Screen recording in progress")
            .setContentText("Tap the meeting app to stop recording.")
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else startForeground(NOTIFICATION_ID, notification)
    }

    fun stopRecording(): Map<String, Any> {
        check(active === this && encoder != null) { "No active recording." }
        stopping = true
        val file = requireNotNull(output)
        val duration = android.os.SystemClock.elapsedRealtime() - startedAtMs
        try {
            encoder?.stop()
            val retriever = MediaMetadataRetriever()
            val validVideo = try {
                retriever.setDataSource(file.absolutePath)
                val video = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO
                ) == "yes"
                val length = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )?.toLongOrNull() ?: 0
                val width = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH
                )?.toIntOrNull() ?: 0
                val height = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT
                )?.toIntOrNull() ?: 0
                video && length > 0 && width > 0 && height > 0
            } finally {
                retriever.release()
            }
            check(validVideo && file.length() > 0) {
                "The screen encoder did not produce valid MP4 video."
            }
            return mapOf(
                "localFilePath" to file.absolutePath,
                "fileName" to file.name,
                "fileSizeBytes" to file.length(),
                "durationMs" to duration,
                "hasVideo" to true,
                "hasAudio" to false
            )
        } catch (error: Exception) {
            Log.e("FlutterRealtimeRecorder", "MP4 finalization failed", error)
            file.delete()
            throw IllegalStateException(
                "Android MP4 finalization failed: ${error.message ?: error.javaClass.simpleName}. " +
                    "Keep recording for at least 3 seconds and ensure screen capture was authorized.",
                error
            )
        } finally {
            cleanup(removeFile = false)
            stopSelf()
        }
    }

    private fun cleanup(removeFile: Boolean) {
        active = null
        virtualDisplay?.release()
        virtualDisplay = null
        encoder?.reset()
        encoder?.release()
        encoder = null
        val previous = projection
        projection = null
        previous?.unregisterCallback(projectionCallback)
        previous?.stop()
        if (removeFile) output?.delete()
        output = null
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onDestroy() {
        if (active === this) cleanup(removeFile = true)
        super.onDestroy()
    }
}

@Suppress("DEPRECATION")
private fun Intent.parcelableResultData(): Intent? =
    if (Build.VERSION.SDK_INT >= 33)
        getParcelableExtra("resultData", Intent::class.java)
    else getParcelableExtra("resultData")
