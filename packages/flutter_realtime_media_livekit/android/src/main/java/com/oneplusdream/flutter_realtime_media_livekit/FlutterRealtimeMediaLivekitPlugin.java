package com.oneplusdream.flutter_realtime_media_livekit;

import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.ResultReceiver;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public final class FlutterRealtimeMediaLivekitPlugin
        implements FlutterPlugin, MethodCallHandler {
    private static final String CHANNEL =
            "flutter_realtime_media_livekit/screen_share";

    private Context applicationContext;
    private MethodChannel channel;
    private MethodChannel processedChannel;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private Result pendingScreenStart;
    private Runnable screenStartTimeout;
    private boolean screenServiceStarted;
    private final java.util.Map<String,ProcessedWebRtcTrack> processedTracks = new java.util.HashMap<>();

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
        processedChannel = new MethodChannel(binding.getBinaryMessenger(), "flutter_realtime_media_livekit/processed_video");
        processedChannel.setMethodCallHandler((call,result) -> {
            String sourceId=call.argument("sourceId");
            try {
                if (sourceId == null || sourceId.trim().isEmpty()) throw new IllegalArgumentException("sourceId is required.");
                if ("create".equals(call.method)) {
                    ProcessedWebRtcTrack old=processedTracks.remove(sourceId);
                    if (old!=null) old.dispose();
                    ProcessedWebRtcTrack track=new ProcessedWebRtcTrack(sourceId);
                    processedTracks.put(sourceId,track); result.success(track.descriptor());
                } else if ("dispose".equals(call.method)) {
                    ProcessedWebRtcTrack old=processedTracks.remove(sourceId);
                    if (old!=null) old.dispose(); result.success(null);
                } else result.notImplemented();
            } catch(Exception error) { result.error("processed_video_failed",error.getMessage(),null); }
        });
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if ("start".equals(call.method)) {
            startForegroundService(result);
            return;
        }
        if ("stop".equals(call.method)) {
            finishScreenStart("screen_share_cancelled", "Screen sharing was stopped before the service was ready.");
            stopForegroundService();
            result.success(null);
            return;
        }
        result.notImplemented();
    }

    private void startForegroundService(Result result) {
        if (applicationContext == null) {
            result.error("screen_share_unavailable", "The Android plugin is detached.", null);
            return;
        }
        if (pendingScreenStart != null) {
            result.error("screen_share_busy", "Screen-sharing service is already starting.", null);
            return;
        }
        pendingScreenStart = result;
        Intent intent = new Intent(applicationContext, ScreenShareForegroundService.class);
        intent.putExtra(ScreenShareForegroundService.EXTRA_RESULT_RECEIVER,
                new ResultReceiver(mainHandler) {
                    @Override protected void onReceiveResult(int code, Bundle data) {
                        // Ignore a late acknowledgment belonging to an earlier start.
                        if (pendingScreenStart != result) return;
                        if (code == ScreenShareForegroundService.RESULT_READY) {
                            screenServiceStarted = true;
                            finishScreenStart(null, null);
                        } else {
                            finishScreenStart("screen_share_service_failed",
                                    data == null ? "Unable to start screen-sharing service."
                                            : data.getString("message"));
                        }
                    }
                });
        screenStartTimeout = () -> {
            finishScreenStart("screen_share_service_timeout", "Screen-sharing service did not become ready.");
            stopForegroundService();
        };
        mainHandler.postDelayed(screenStartTimeout, 10_000);
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(intent);
            } else {
                applicationContext.startService(intent);
            }
        } catch (RuntimeException error) {
            finishScreenStart("screen_share_service_failed", error.getMessage());
        }
    }

    private void finishScreenStart(String code, String message) {
        if (screenStartTimeout != null) mainHandler.removeCallbacks(screenStartTimeout);
        screenStartTimeout = null;
        Result result = pendingScreenStart;
        pendingScreenStart = null;
        if (result == null) return;
        if (code == null) result.success(null);
        else result.error(code, message, null);
    }

    private void stopForegroundService() {
        if (applicationContext == null) return;
        Intent intent = new Intent(applicationContext, ScreenShareForegroundService.class);
        applicationContext.stopService(intent);
        screenServiceStarted = false;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        final boolean shouldStopScreenService = screenServiceStarted || pendingScreenStart != null;
        finishScreenStart("screen_share_unavailable", "The Android plugin was detached.");
        if (shouldStopScreenService) stopForegroundService();
        for (ProcessedWebRtcTrack track: processedTracks.values()) track.dispose();
        processedTracks.clear();
        if (processedChannel != null) processedChannel.setMethodCallHandler(null);
        if (channel != null) channel.setMethodCallHandler(null);
        channel = null;
        applicationContext = null;
    }
}
