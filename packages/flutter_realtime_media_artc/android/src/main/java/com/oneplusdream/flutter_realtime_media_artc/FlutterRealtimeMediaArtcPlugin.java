package com.oneplusdream.flutter_realtime_media_artc;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;

import com.alivc.rtc.AliRtcEngine;
import com.alivc.rtc.AliRtcEngineEventListener;
import com.alivc.rtc.AliRtcEngineNotify;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.json.JSONException;
import org.json.JSONObject;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;

/** Flutter bridge for Alibaba Cloud's Android ARTC SDK. */
public final class FlutterRealtimeMediaArtcPlugin implements
        FlutterPlugin,
        MethodChannel.MethodCallHandler,
        EventChannel.StreamHandler,
        ActivityAware,
        PluginRegistry.RequestPermissionsResultListener {

    private static final String METHOD_CHANNEL = "com.oneplusdream.flutter_realtime_media_artc/methods";
    private static final String EVENT_CHANNEL = "com.oneplusdream.flutter_realtime_media_artc/events";
    private static final String VIEW_TYPE = "com.oneplusdream.flutter_realtime_media_artc/video";
    private static final int PERMISSION_REQUEST_CODE = 0x4152;
    private static final long JOIN_TIMEOUT_MS = 20_000;
    private static final long LEAVE_TIMEOUT_MS = 4_000;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final List<ArtcVideoPlatformView> videoViews = new ArrayList<>();

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private FlutterPluginBinding pluginBinding;
    private ActivityPluginBinding activityBinding;
    private Activity activity;
    private AliRtcEngine engine;
    private MethodChannel.Result pendingJoinResult;
    private MethodChannel.Result pendingLeaveResult;
    private MethodChannel.Result pendingPermissionResult;
    private Runnable pendingPermissionAction;
    private Runnable joinTimeout;
    private Runnable leaveTimeout;
    private String localUserId;
    private boolean viewer;
    private boolean inChannel;
    private boolean disposed;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        pluginBinding = binding;
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        methodChannel.setMethodCallHandler(this);
        eventChannel.setStreamHandler(this);
        binding.getPlatformViewRegistry().registerViewFactory(
                VIEW_TYPE,
                new PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                    @NonNull
                    @Override
                    public PlatformView create(@NonNull Context context, int viewId, @Nullable Object args) {
                        Map<?, ?> values = args instanceof Map ? (Map<?, ?>) args : new HashMap<>();
                        String userId = String.valueOf(values.get("userId"));
                        boolean isLocal = Boolean.TRUE.equals(values.get("isLocal"));
                        ArtcVideoPlatformView platformView = new ArtcVideoPlatformView(
                                context, userId, isLocal, FlutterRealtimeMediaArtcPlugin.this);
                        videoViews.add(platformView);
                        platformView.attach(engine);
                        return platformView;
                    }
                });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (methodChannel != null) methodChannel.setMethodCallHandler(null);
        if (eventChannel != null) eventChannel.setStreamHandler(null);
        disposeEngine();
        for (ArtcVideoPlatformView view : new ArrayList<>(videoViews)) view.dispose();
        videoViews.clear();
        pluginBinding = null;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        eventSink = events;
    }

    @Override
    public void onCancel(Object arguments) {
        eventSink = null;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "join": join(call, result); break;
            case "leave": leave(result); break;
            case "setMuted": setMuted(call, result); break;
            case "setVideoEnabled": setVideoEnabled(call, result); break;
            case "switchCamera": switchCamera(call, result); break;
            case "sendMessage": sendMessage(call, result); break;
            case "dispose": disposeEngine(); result.success(null); break;
            default: result.notImplemented();
        }
    }

    private void join(MethodCall call, MethodChannel.Result result) {
        if (disposed) {
            error(result, "invalid_state", "ARTC plugin has been detached.");
            return;
        }
        if (engine != null && inChannel) {
            error(result, "invalid_state", "Leave the current ARTC channel before joining another.");
            return;
        }
        String appId = string(call, "appId");
        String channelId = string(call, "channelId");
        String userId = string(call, "userId");
        String authInfo = string(call, "authInfo");
        String displayName = string(call, "displayName");
        String role = string(call, "role");
        String roomMode = string(call, "roomMode");
        if (appId.isEmpty() || channelId.isEmpty() || userId.isEmpty() || authInfo.isEmpty()
                || !("participant".equals(role) || "host".equals(role) || "viewer".equals(role))) {
            error(result, "invalid_join_info", "ARTC join data is missing or invalid.");
            return;
        }
        if ("participant".equals(role) != "communication".equals(roomMode)) {
            error(result, "invalid_join_info", "ARTC role does not match its channel mode.");
            return;
        }
        try {
            if (engine == null) {
                engine = AliRtcEngine.getInstance(pluginBinding.getApplicationContext());
                engine.setRtcEngineEventListener(eventListener);
                engine.setRtcEngineNotify(engineNotify);
                engine.setParameter("{\"data\":{\"enablePubDataChannel\":true,\"enableSubDataChannel\":true}}");
            }
            boolean interactive = "interactiveLive".equals(roomMode);
            int profileResult = engine.setChannelProfile(interactive
                    ? AliRtcEngine.AliRTCSdkChannelProfile.AliRTCSdkInteractiveLive
                    : AliRtcEngine.AliRTCSdkChannelProfile.AliRTCSdkCommunication);
            if (profileResult != 0) {
                error(result, "native_error", "ARTC rejected the channel profile (" + profileResult + ").");
                return;
            }
            viewer = "viewer".equals(role);
            if (interactive) {
                int roleResult = engine.setClientRole(viewer
                        ? AliRtcEngine.AliRTCSdkClientRole.AliRTCSdkLive
                        : AliRtcEngine.AliRTCSdkClientRole.AliRTCSdkInteractive);
                if (roleResult != 0) {
                    error(result, "native_error", "ARTC rejected the client role (" + roleResult + ").");
                    return;
                }
            }
            localUserId = userId;
            engine.publishLocalAudioStream(false);
            engine.publishLocalVideoStream(false);
            engine.enableLocalVideo(false);
            pendingJoinResult = result;
            joinTimeout = () -> {
                MethodChannel.Result pending = pendingJoinResult;
                pendingJoinResult = null;
                if (pending != null) error(pending, "native_error", "ARTC channel join timed out.");
            };
            mainHandler.postDelayed(joinTimeout, JOIN_TIMEOUT_MS);
            int joinCode = engine.joinChannel(authInfo, channelId, userId, displayName);
            if (joinCode != 0) {
                clearJoinTimeout();
                pendingJoinResult = null;
                error(result, "native_error", "ARTC failed to start joining (" + joinCode + ").");
            }
        } catch (Throwable throwable) {
            clearJoinTimeout();
            pendingJoinResult = null;
            error(result, "native_error", throwable.getMessage() == null ? "ARTC initialization failed." : throwable.getMessage());
        }
    }

    private void leave(MethodChannel.Result result) {
        if (engine == null || !inChannel) {
            result.success(null);
            return;
        }
        if (pendingLeaveResult != null) {
            error(result, "invalid_state", "ARTC leave is already in progress.");
            return;
        }
        pendingLeaveResult = result;
        leaveTimeout = () -> finishLeave("ARTC did not confirm channel leave before timeout.");
        mainHandler.postDelayed(leaveTimeout, LEAVE_TIMEOUT_MS);
        int leaveCode = engine.leaveChannel();
        if (leaveCode != 0) finishLeave("ARTC failed to leave the channel (" + leaveCode + ").");
    }

    private void setMuted(MethodCall call, MethodChannel.Result result) {
        if (!requirePublisher(result)) return;
        boolean muted = Boolean.TRUE.equals(call.argument("muted"));
        if (muted) {
            int code = engine.publishLocalAudioStream(false);
            if (code == 0) result.success(null); else nativeError(result, "ARTC failed to stop publishing audio", code);
            return;
        }
        withPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, result, () -> {
            int code = engine.publishLocalAudioStream(true);
            if (code == 0) result.success(null); else nativeError(result, "ARTC failed to publish audio", code);
        });
    }

    private void setVideoEnabled(MethodCall call, MethodChannel.Result result) {
        if (!requirePublisher(result)) return;
        boolean enabled = Boolean.TRUE.equals(call.argument("enabled"));
        if (!enabled) {
            int publishCode = engine.publishLocalVideoStream(false);
            int captureCode = engine.enableLocalVideo(false);
            if (publishCode == 0 && captureCode == 0) result.success(null);
            else nativeError(result, "ARTC failed to disable local video", publishCode != 0 ? publishCode : captureCode);
            return;
        }
        withPermissions(new String[]{Manifest.permission.CAMERA}, result, () -> {
            int captureCode = engine.enableLocalVideo(true);
            int publishCode = captureCode == 0 ? engine.publishLocalVideoStream(true) : captureCode;
            if (publishCode == 0) result.success(null);
            else nativeError(result, "ARTC failed to enable local video", publishCode);
        });
    }

    private void switchCamera(MethodCall call, MethodChannel.Result result) {
        if (!requirePublisher(result)) return;
        if (engine == null || !engine.isCameraOn()) {
            error(result, "invalid_state", "Enable the camera before switching cameras.");
            return;
        }
        String requested = string(call, "position");
        AliRtcEngine.AliRtcCameraDirection direction = engine.getCurrentCameraDirection();
        boolean wantsFront = "front".equals(requested);
        if ((wantsFront && direction == AliRtcEngine.AliRtcCameraDirection.CAMERA_FRONT)
                || (!wantsFront && direction == AliRtcEngine.AliRtcCameraDirection.CAMERA_REAR)) {
            result.success(null);
            return;
        }
        int code = engine.switchCamera();
        if (code == 0) result.success(null); else nativeError(result, "ARTC failed to switch cameras", code);
    }

    private void sendMessage(MethodCall call, MethodChannel.Result result) {
        if (!requirePublisher(result)) return;
        String message = string(call, "message");
        String topic = string(call, "topic");
        byte[] payload;
        try {
            JSONObject envelope = new JSONObject();
            envelope.put("topic", topic);
            envelope.put("message", message);
            payload = envelope.toString().getBytes(StandardCharsets.UTF_8);
        } catch (JSONException exception) {
            error(result, "invalid_argument", "ARTC message could not be encoded.");
            return;
        }
        AliRtcEngine.AliRtcDataChannelMsg data = new AliRtcEngine.AliRtcDataChannelMsg();
        data.type = AliRtcEngine.AliRtcDataMsgType.AliEngineDataMsgCustom;
        data.data = payload;
        int code = engine.sendDataChannelMsg(data);
        if (code == 0) result.success(null); else nativeError(result, "ARTC failed to send the data message", code);
    }

    private boolean requirePublisher(MethodChannel.Result result) {
        if (engine == null || !inChannel) {
            error(result, "invalid_state", "ARTC controls require an active channel.");
            return false;
        }
        if (viewer) {
            error(result, "unsupported_feature", "ARTC viewer sessions cannot publish or send data.");
            return false;
        }
        return true;
    }

    private void withPermissions(String[] permissions, MethodChannel.Result result, Runnable action) {
        Activity current = activity;
        if (current == null) {
            error(result, "permission_denied", "An attached Activity is required to request ARTC media permissions.");
            return;
        }
        List<String> missing = new ArrayList<>();
        for (String permission : permissions) {
            if (Build.VERSION.SDK_INT < 23 || ActivityCompat.checkSelfPermission(current, permission) == PackageManager.PERMISSION_GRANTED) continue;
            missing.add(permission);
        }
        if (missing.isEmpty()) {
            action.run();
            return;
        }
        if (pendingPermissionResult != null) {
            error(result, "invalid_state", "An ARTC permission request is already in progress.");
            return;
        }
        if (activityBinding == null) {
            error(result, "permission_denied", "The ARTC permission request cannot be started.");
            return;
        }
        pendingPermissionResult = result;
        pendingPermissionAction = action;
        ActivityCompat.requestPermissions(current, missing.toArray(new String[0]), PERMISSION_REQUEST_CODE);
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if (requestCode != PERMISSION_REQUEST_CODE) return false;
        MethodChannel.Result result = pendingPermissionResult;
        Runnable action = pendingPermissionAction;
        pendingPermissionResult = null;
        pendingPermissionAction = null;
        if (result == null) return true;
        if (grantResults.length == 0) {
            error(result, "permission_denied", "Camera or microphone permission was not granted.");
            return true;
        }
        for (int grant : grantResults) {
            if (grant != PackageManager.PERMISSION_GRANTED) {
                error(result, "permission_denied", "Camera or microphone permission was denied.");
                return true;
            }
        }
        if (action != null) action.run();
        return true;
    }

    private final AliRtcEngineEventListener eventListener = new AliRtcEngineEventListener() {
        @Override
        public void onJoinChannelResult(int result, String channel, String userId, int elapsed) {
            mainHandler.post(() -> {
                clearJoinTimeout();
                MethodChannel.Result pending = pendingJoinResult;
                pendingJoinResult = null;
                if (result == 0) {
                    inChannel = true;
                    attachViews();
                    if (pending != null) pending.success(null);
                } else {
                    inChannel = false;
                    emit(event("error", "code", result, "message", "ARTC failed to join channel."));
                    if (pending != null) error(pending, "native_error", "ARTC failed to join channel (" + result + ").");
                }
            });
        }

        @Override
        public void onLeaveChannelResult(int result, AliRtcEngine.AliRtcStats stats) {
            mainHandler.post(() -> finishLeave(result == 0 ? null : "ARTC leave completed with error " + result + "."));
        }

        @Override
        public void onOccurError(int code, String message) {
            emit(event("error", "code", code, "message", message));
        }

        @Override
        public void onTryToReconnect() { emit(event("reconnecting")); }

        @Override
        public void onConnectionLost() { emit(event("reconnecting")); }

        @Override
        public void onConnectionRecovery() { emit(event("recovered")); }

        @Override
        public void onConnectionStatusChange(AliRtcEngine.AliRtcConnectionStatus status,
                                             AliRtcEngine.AliRtcConnectionStatusChangeReason reason) {
            if (status == AliRtcEngine.AliRtcConnectionStatus.AliRtcConnectionStatusReconnecting
                    || status == AliRtcEngine.AliRtcConnectionStatus.AliRtcConnectionStatusDisconnected) {
                emit(event("reconnecting"));
            } else if (status == AliRtcEngine.AliRtcConnectionStatus.AliRtcConnectionStatusConnected) {
                emit(event("recovered"));
            }
        }
    };

    private final AliRtcEngineNotify engineNotify = new AliRtcEngineNotify() {
        @Override
        public void onRemoteUserOnLineNotify(String userId, int elapsed) {
            emit(event("participantJoined", "userId", userId));
        }

        @Override
        public void onRemoteUserOffLineNotify(String userId, AliRtcEngine.AliRtcUserOfflineReason reason) {
            emit(event("participantLeft", "userId", userId));
        }

        @Override
        public void onRemoteTrackAvailableNotify(String userId, AliRtcEngine.AliRtcAudioTrack audio,
                                                 AliRtcEngine.AliRtcVideoTrack video) {
            boolean hasAudio = audio != AliRtcEngine.AliRtcAudioTrack.AliRtcAudioTrackNo;
            boolean hasVideo = video != AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackNo;
            emit(event("audioChanged", "userId", userId, "available", hasAudio));
            emit(event("videoChanged", "userId", userId, "available", hasVideo));
        }

        @Override
        public void onUserAudioMuted(String userId, boolean muted) {
            emit(event("audioChanged", "userId", userId, "available", !muted));
        }

        @Override
        public void onUserVideoMuted(String userId, boolean muted) {
            emit(event("videoChanged", "userId", userId, "available", !muted));
        }

        @Override
        public void onAuthInfoWillExpire() { emit(event("authWillExpire")); }

        @Override
        public void onAuthInfoExpired() { emit(event("authWillExpire")); }

        @Override
        public void onDataChannelMessage(String userId, AliRtcEngine.AliRtcDataChannelMsg message) {
            String data = message.data == null ? "" : new String(message.data, StandardCharsets.UTF_8);
            emit(event("message", "userId", userId, "data", data));
        }
    };

    private void finishLeave(@Nullable String failure) {
        if (leaveTimeout != null) mainHandler.removeCallbacks(leaveTimeout);
        leaveTimeout = null;
        inChannel = false;
        detachViews();
        MethodChannel.Result result = pendingLeaveResult;
        pendingLeaveResult = null;
        if (result == null) return;
        if (failure == null) result.success(null); else error(result, "native_error", failure);
    }

    private void disposeEngine() {
        disposed = true;
        clearJoinTimeout();
        if (leaveTimeout != null) mainHandler.removeCallbacks(leaveTimeout);
        leaveTimeout = null;
        if (pendingJoinResult != null) error(pendingJoinResult, "invalid_state", "ARTC engine disposed during join.");
        pendingJoinResult = null;
        if (pendingLeaveResult != null) pendingLeaveResult.success(null);
        pendingLeaveResult = null;
        if (pendingPermissionResult != null) error(pendingPermissionResult, "permission_denied", "ARTC engine disposed during permission request.");
        pendingPermissionResult = null;
        pendingPermissionAction = null;
        detachViews();
        AliRtcEngine oldEngine = engine;
        engine = null;
        inChannel = false;
        localUserId = null;
        if (oldEngine != null) {
            try {
                oldEngine.setRtcEngineEventListener(null);
                oldEngine.setRtcEngineNotify(null);
                oldEngine.destroy();
            } catch (Throwable ignored) { }
        }
        disposed = false;
    }

    private void attachViews() {
        for (ArtcVideoPlatformView view : new ArrayList<>(videoViews)) view.attach(engine);
    }

    private void detachViews() {
        for (ArtcVideoPlatformView view : new ArrayList<>(videoViews)) view.detach(engine);
    }

    private void removeVideoView(ArtcVideoPlatformView view) {
        videoViews.remove(view);
        view.detach(engine);
    }

    private void clearJoinTimeout() {
        if (joinTimeout != null) mainHandler.removeCallbacks(joinTimeout);
        joinTimeout = null;
    }

    private void emit(Map<String, Object> event) {
        mainHandler.post(() -> {
            if (eventSink != null) eventSink.success(event);
        });
    }

    private static Map<String, Object> event(Object... pairs) {
        Map<String, Object> result = new HashMap<>();
        for (int index = 0; index + 1 < pairs.length; index += 2) result.put(String.valueOf(pairs[index]), pairs[index + 1]);
        return result;
    }

    private static String string(MethodCall call, String key) {
        Object value = call.argument(key);
        return value == null ? "" : String.valueOf(value);
    }

    private static void error(MethodChannel.Result result, String code, String message) {
        result.error(code, message, null);
    }

    private static void nativeError(MethodChannel.Result result, String message, int code) {
        error(result, "native_error", message + " (" + code + ").");
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
        activity = binding.getActivity();
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() { detachActivity(); }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) { onAttachedToActivity(binding); }

    @Override
    public void onDetachedFromActivity() { detachActivity(); }

    private void detachActivity() {
        if (activityBinding != null) activityBinding.removeRequestPermissionsResultListener(this);
        activityBinding = null;
        activity = null;
    }

    private static final class ArtcVideoPlatformView implements PlatformView {
        private final Context context;
        private final String userId;
        private final boolean local;
        private final FlutterRealtimeMediaArtcPlugin plugin;
        private final FrameLayout container;
        private AliRtcEngine boundEngine;
        private View sdkView;

        ArtcVideoPlatformView(Context context, String userId, boolean local, FlutterRealtimeMediaArtcPlugin plugin) {
            this.context = context;
            this.userId = userId;
            this.local = local;
            this.plugin = plugin;
            this.container = new FrameLayout(context);
        }

        void attach(@Nullable AliRtcEngine currentEngine) {
            detach(boundEngine);
            if (currentEngine == null || (local && !plugin.inChannel)) return;
            boundEngine = currentEngine;
            sdkView = currentEngine.createRenderSurfaceView(context);
            if (sdkView == null) return;
            container.addView(sdkView, new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
            AliRtcEngine.AliRtcVideoCanvas canvas = new AliRtcEngine.AliRtcVideoCanvas();
            canvas.view = sdkView;
            canvas.renderMode = AliRtcEngine.AliRtcRenderMode.AliRtcRenderModeFill;
            if (local) {
                currentEngine.setLocalViewConfig(canvas, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera);
                if (currentEngine.isCameraOn()) currentEngine.startPreview();
            } else {
                currentEngine.setRemoteViewConfig(canvas, userId, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera);
            }
        }

        void detach(@Nullable AliRtcEngine currentEngine) {
            AliRtcEngine target = boundEngine != null ? boundEngine : currentEngine;
            if (target != null) {
                try {
                    if (local) target.setLocalViewConfig(null, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera);
                    else target.setRemoteViewConfig(null, userId, AliRtcEngine.AliRtcVideoTrack.AliRtcVideoTrackCamera);
                } catch (Throwable ignored) { }
            }
            if (sdkView != null) container.removeView(sdkView);
            sdkView = null;
            boundEngine = null;
        }

        @NonNull
        @Override
        public View getView() { return container; }

        @Override
        public void dispose() { plugin.removeVideoView(this); }
    }
}
