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

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
        channel.setMethodCallHandler(this);
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
        if (channel != null) channel.setMethodCallHandler(null);
        channel = null;
        applicationContext = null;
    }
}
