package com.oneplusdream.flutter_realtime_media_livekit;

import android.content.Context;
import android.content.Intent;
import android.os.Build;

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
            startForegroundService();
            result.success(null);
            return;
        }
        if ("stop".equals(call.method)) {
            stopForegroundService();
            result.success(null);
            return;
        }
        result.notImplemented();
    }

    private void startForegroundService() {
        if (applicationContext == null) return;
        Intent intent = new Intent(applicationContext, ScreenShareForegroundService.class);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            applicationContext.startForegroundService(intent);
        } else {
            applicationContext.startService(intent);
        }
    }

    private void stopForegroundService() {
        if (applicationContext == null) return;
        Intent intent = new Intent(applicationContext, ScreenShareForegroundService.class);
        applicationContext.stopService(intent);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        for (ProcessedWebRtcTrack track: processedTracks.values()) track.dispose();
        processedTracks.clear();
        if (processedChannel != null) processedChannel.setMethodCallHandler(null);
        if (channel != null) channel.setMethodCallHandler(null);
        channel = null;
        applicationContext = null;
    }
}
