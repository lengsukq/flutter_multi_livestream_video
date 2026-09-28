package com.oneplusdream.flutter_realtime_media_ivs;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.amazonaws.ivs.broadcast.AudioLocalStageStream;
import com.amazonaws.ivs.broadcast.BroadcastException;
import com.amazonaws.ivs.broadcast.Device;
import com.amazonaws.ivs.broadcast.DeviceDiscovery;
import com.amazonaws.ivs.broadcast.ImageLocalStageStream;
import com.amazonaws.ivs.broadcast.ImagePreviewSurfaceView;
import com.amazonaws.ivs.broadcast.ImageStageStream;
import com.amazonaws.ivs.broadcast.LocalAudioStats;
import com.amazonaws.ivs.broadcast.LocalStageStream;
import com.amazonaws.ivs.broadcast.LocalVideoStats;
import com.amazonaws.ivs.broadcast.ParticipantInfo;
import com.amazonaws.ivs.broadcast.RemoteAudioStats;
import com.amazonaws.ivs.broadcast.RemoteStageStream;
import com.amazonaws.ivs.broadcast.RemoteVideoStats;
import com.amazonaws.ivs.broadcast.Stage;
import com.amazonaws.ivs.broadcast.StageRenderer;
import com.amazonaws.ivs.broadcast.StageStream;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import io.flutter.plugin.common.StandardMessageCodec;

public final class FlutterRealtimeMediaIvsPlugin
        implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
        EventChannel.StreamHandler, StageRenderer {

    private static final String METHOD_CHANNEL =
            "com.oneplusdream.flutter_realtime_media_ivs/methods";
    private static final String EVENT_CHANNEL =
            "com.oneplusdream.flutter_realtime_media_ivs/events";
    private static final String VIEW_TYPE =
            "com.oneplusdream.flutter_realtime_media_ivs/video";
    private static final String LOCAL_VIEW_KEY = "__local__";

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final List<LocalStageStream> publishStreams = new ArrayList<>();
    private final Map<String, ImageStageStream> remoteVideoStreams = new HashMap<>();
    private final Map<String, List<FrameLayout>> previewHolders = new HashMap<>();
    private final List<StageStream> observedStreams = new ArrayList<>();

    private Context applicationContext;
    private Activity activity;
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private DeviceDiscovery deviceDiscovery;
    private Stage stage;
    private ImageLocalStageStream cameraStream;
    private AudioLocalStageStream microphoneStream;
    private boolean shouldPublish;
    private boolean connectedOnce;
    private MethodChannel.Result pendingJoinResult;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        applicationContext = binding.getApplicationContext();
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);
        binding
                .getPlatformViewRegistry()
                .registerViewFactory(VIEW_TYPE, new IvsVideoViewFactory(this));
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        disposeNative();
        if (methodChannel != null) methodChannel.setMethodCallHandler(null);
        if (eventChannel != null) eventChannel.setStreamHandler(null);
        methodChannel = null;
        eventChannel = null;
        applicationContext = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(
            @NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
    }

    @Override
    public void onDetachedFromActivity() {
        activity = null;
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
        try {
            switch (call.method) {
                case "probeDevices":
                    result.success(probeDevices());
                    return;
                case "join":
                    join(call, result);
                    return;
                case "exchangeToken":
                    requireStage().exchangeToken(requireString(call, "token"));
                    result.success(null);
                    return;
                case "leave":
                    leaveNative();
                    result.success(null);
                    return;
                case "setMuted":
                    setMuted(Boolean.TRUE.equals(call.argument("muted")));
                    result.success(null);
                    return;
                case "setVideoEnabled":
                    setVideoEnabled(Boolean.TRUE.equals(call.argument("enabled")));
                    result.success(null);
                    return;
                case "switchCamera":
                    switchCamera(requireString(call, "position"));
                    result.success(null);
                    return;
                case "requestStats":
                    requestStats();
                    result.success(null);
                    return;
                case "dispose":
                    disposeNative();
                    result.success(null);
                    return;
                default:
                    result.notImplemented();
            }
        } catch (SecurityException error) {
            result.error("permission_denied", error.getMessage(), null);
        } catch (IllegalStateException error) {
            result.error("invalid_state", error.getMessage(), null);
        } catch (IllegalArgumentException error) {
            result.error("invalid_join_info", error.getMessage(), null);
        } catch (Exception error) {
            result.error("native_error", error.getMessage(), error.toString());
        }
    }

    private Map<String, Object> probeDevices() {
        final DeviceDiscovery discovery = requireDeviceDiscovery();
        int cameras = 0;
        int microphones = 0;
        for (Device device : discovery.listLocalDevices()) {
            if (device.getDescriptor().type == Device.Descriptor.DeviceType.CAMERA) {
                cameras++;
            } else if (device.getDescriptor().type == Device.Descriptor.DeviceType.MICROPHONE) {
                microphones++;
            }
        }
        final Map<String, Object> value = new HashMap<>();
        value.put("cameras", cameras);
        value.put("microphones", microphones);
        return value;
    }

    private void join(MethodCall call, MethodChannel.Result result) {
        if (stage != null) {
            throw new IllegalStateException("An IVS Stage is already active.");
        }
        final String token = requireString(call, "token");
        final String role = requireString(call, "role");
        shouldPublish = !"viewer".equals(role);
        connectedOnce = false;
        prepareLocalStreams();

        final Stage.Strategy strategy = new Stage.Strategy() {
            @NonNull
            @Override
            public List<LocalStageStream> stageStreamsToPublishForParticipant(
                    @NonNull Stage stage,
                    @NonNull ParticipantInfo participantInfo) {
                return new ArrayList<>(publishStreams);
            }

            @Override
            public boolean shouldPublishFromParticipant(
                    @NonNull Stage stage,
                    @NonNull ParticipantInfo participantInfo) {
                return shouldPublish;
            }

            @NonNull
            @Override
            public Stage.SubscribeType shouldSubscribeToParticipant(
                    @NonNull Stage stage,
                    @NonNull ParticipantInfo participantInfo) {
                return participantInfo.isLocal
                        ? Stage.SubscribeType.NONE
                        : Stage.SubscribeType.AUDIO_VIDEO;
            }
        };

        pendingJoinResult = result;
        stage = new Stage(requireContext(), token, strategy);
        stage.addRenderer(this);
        stage.join();
    }

    private void prepareLocalStreams() {
        publishStreams.clear();
        cameraStream = null;
        microphoneStream = null;
        if (!shouldPublish) {
            updateLocalPreviewHolders(null);
            return;
        }

        Device frontCamera = null;
        Device fallbackCamera = null;
        Device defaultMicrophone = null;
        Device fallbackMicrophone = null;
        for (Device device : requireDeviceDiscovery().listLocalDevices()) {
            final Device.Descriptor descriptor = device.getDescriptor();
            if (descriptor.type == Device.Descriptor.DeviceType.CAMERA) {
                if (fallbackCamera == null) fallbackCamera = device;
                if (descriptor.position == Device.Descriptor.Position.FRONT) {
                    frontCamera = device;
                }
            } else if (descriptor.type == Device.Descriptor.DeviceType.MICROPHONE) {
                if (fallbackMicrophone == null) fallbackMicrophone = device;
                if (descriptor.isDefault) defaultMicrophone = device;
            }
        }
        final Device camera = frontCamera != null ? frontCamera : fallbackCamera;
        final Device microphone =
                defaultMicrophone != null ? defaultMicrophone : fallbackMicrophone;
        if (camera != null) {
            cameraStream = new ImageLocalStageStream(camera);
            cameraStream.setMuted(true);
            publishStreams.add(cameraStream);
            observeStream(cameraStream);
        }
        if (microphone != null) {
            microphoneStream = new AudioLocalStageStream(microphone);
            microphoneStream.setMuted(true);
            publishStreams.add(microphoneStream);
            observeStream(microphoneStream);
        }
        updateLocalPreviewHolders(cameraStream);
    }

    private void setMuted(boolean muted) {
        requireStage();
        if (microphoneStream == null) {
            if (!muted) throw new IllegalStateException("No IVS microphone is available.");
            return;
        }
        microphoneStream.setMuted(muted);
    }

    private void setVideoEnabled(boolean enabled) {
        requireStage();
        if (cameraStream == null) {
            if (enabled) throw new IllegalStateException("No IVS camera is available.");
            return;
        }
        cameraStream.setMuted(!enabled);
        updateLocalPreviewHolders(cameraStream);
    }

    private void switchCamera(String position) {
        requireStage();
        final Device.Descriptor.Position desired =
                "back".equals(position)
                        ? Device.Descriptor.Position.BACK
                        : Device.Descriptor.Position.FRONT;
        Device replacement = null;
        for (Device device : requireDeviceDiscovery().listLocalDevices()) {
            final Device.Descriptor descriptor = device.getDescriptor();
            if (descriptor.type == Device.Descriptor.DeviceType.CAMERA
                    && descriptor.position == desired) {
                replacement = device;
                break;
            }
        }
        if (replacement == null) {
            throw new IllegalStateException("Requested IVS camera is unavailable.");
        }
        final boolean muted = cameraStream == null || cameraStream.getMuted();
        if (cameraStream != null) publishStreams.remove(cameraStream);
        cameraStream = new ImageLocalStageStream(replacement);
        cameraStream.setMuted(muted);
        publishStreams.add(0, cameraStream);
        observeStream(cameraStream);
        stage.refreshStrategy();
        updateLocalPreviewHolders(cameraStream);
    }

    private void requestStats() {
        for (StageStream stream : new ArrayList<>(observedStreams)) {
            stream.requestRTCStats();
        }
    }

    private void observeStream(StageStream stream) {
        if (!observedStreams.contains(stream)) observedStreams.add(stream);
        stream.setListener(new StageStream.Listener() {
            @Override
            public void onMutedChanged(boolean muted) {
                // StageRenderer supplies participant context for remote mute changes.
            }

            @Override
            public void onRTCStats(
                    @NonNull Map<String, Map<String, String>> statsMap) {
                emitStats(statsMap);
            }

            @Override
            public void onLocalAudioStats(@NonNull LocalAudioStats stats) {}

            @Override
            public void onLocalVideoStats(@NonNull List<LocalVideoStats> stats) {}

            @Override
            public void onRemoteAudioStats(@NonNull RemoteAudioStats stats) {}

            @Override
            public void onRemoteVideoStats(@NonNull RemoteVideoStats stats) {}
        });
    }

    private void emitStats(Map<String, Map<String, String>> reports) {
        Double rttSeconds = findStat(reports, "currentRoundTripTime", "roundTripTime");
        Double jitterSeconds = findStat(reports, "jitter");
        Double packetsLost = findStat(reports, "packetsLost");
        Double packetsTotal = firstPositive(
                findStat(reports, "packetsReceived"),
                findStat(reports, "packetsSent"));
        Double bytesSent = findStat(reports, "bytesSent");
        Double bytesReceived = findStat(reports, "bytesReceived");

        final Map<String, Object> event = new HashMap<>();
        event.put("type", "stats");
        if (rttSeconds != null) event.put("rttMs", Math.round(rttSeconds * 1000));
        if (jitterSeconds != null) event.put("jitterMs", Math.round(jitterSeconds * 1000));
        if (packetsLost != null && packetsTotal != null && packetsTotal > 0) {
            event.put(
                    "downlinkPacketLossPercent",
                    Math.max(0.0, packetsLost * 100.0 / (packetsTotal + packetsLost)));
        }
        if (bytesSent != null) event.put("uploadBytes", bytesSent.longValue());
        if (bytesReceived != null) event.put("downloadBytes", bytesReceived.longValue());
        emit(event);
    }

    @Nullable
    private static Double findStat(
            Map<String, Map<String, String>> reports,
            String... keys) {
        for (Map<String, String> report : reports.values()) {
            for (String key : keys) {
                final String raw = report.get(key);
                if (raw == null) continue;
                try {
                    return Double.parseDouble(raw);
                } catch (NumberFormatException ignored) {
                    // Continue searching another report.
                }
            }
        }
        return null;
    }

    @Nullable
    private static Double firstPositive(@Nullable Double first, @Nullable Double second) {
        if (first != null && first > 0) return first;
        return second != null && second > 0 ? second : null;
    }

    private void leaveNative() {
        final Stage current = stage;
        if (current == null) return;
        current.leave();
        current.removeRenderer(this);
        current.release();
        stage = null;
        pendingJoinResult = null;
        connectedOnce = false;
        remoteVideoStreams.clear();
        observedStreams.clear();
        publishStreams.clear();
        cameraStream = null;
        microphoneStream = null;
        clearAllPreviewHolders();
    }

    private void disposeNative() {
        leaveNative();
        if (deviceDiscovery != null) {
            deviceDiscovery.release();
            deviceDiscovery = null;
        }
    }

    private Stage requireStage() {
        if (stage == null) throw new IllegalStateException("No active IVS Stage.");
        return stage;
    }

    private DeviceDiscovery requireDeviceDiscovery() {
        if (deviceDiscovery == null) {
            deviceDiscovery = new DeviceDiscovery(requireContext());
        }
        return deviceDiscovery;
    }

    private Context requireContext() {
        final Context context = activity != null ? activity : applicationContext;
        if (context == null) throw new IllegalStateException("IVS plugin is detached.");
        return context;
    }

    private static String requireString(MethodCall call, String key) {
        final Object raw = call.argument(key);
        final String value = raw == null ? "" : raw.toString().trim();
        if (value.isEmpty()) throw new IllegalArgumentException(key + " is required.");
        return value;
    }

    private void emit(Map<String, Object> event) {
        final EventChannel.EventSink sink = eventSink;
        if (sink == null) return;
        mainHandler.post(() -> {
            final EventChannel.EventSink current = eventSink;
            if (current != null) current.success(event);
        });
    }

    private static String displayName(ParticipantInfo participant) {
        final String value = participant.attributes.get("displayName");
        return value == null || value.trim().isEmpty() ? participant.userId : value;
    }

    private void emitParticipant(String type, ParticipantInfo participant) {
        if (participant.isLocal) return;
        final Map<String, Object> event = new HashMap<>();
        event.put("type", type);
        event.put("userId", participant.userId);
        event.put("displayName", displayName(participant));
        emit(event);
    }

    private void emitStreamAvailability(
            ParticipantInfo participant,
            StageStream stream,
            boolean available) {
        if (participant.isLocal) return;
        final Map<String, Object> event = new HashMap<>();
        event.put(
                "type",
                stream.getStreamType() == StageStream.Type.VIDEO
                        ? "videoChanged"
                        : "audioChanged");
        event.put("userId", participant.userId);
        event.put("available", available && !stream.getMuted());
        emit(event);
    }

    @Override
    public void onConnectionStateChanged(
            @NonNull Stage stage,
            @NonNull Stage.ConnectionState state,
            @Nullable BroadcastException exception) {
        if (state == Stage.ConnectionState.CONNECTED) {
            if (pendingJoinResult != null) {
                pendingJoinResult.success(null);
                pendingJoinResult = null;
            } else if (connectedOnce) {
                emit(typeOnly("recovered"));
            }
            connectedOnce = true;
            return;
        }
        if (state == Stage.ConnectionState.CONNECTING && connectedOnce) {
            emit(typeOnly("reconnecting"));
            return;
        }
        if (state == Stage.ConnectionState.DISCONNECTED
                && pendingJoinResult != null
                && exception != null) {
            pendingJoinResult.error("native_error", exception.getMessage(), null);
            pendingJoinResult = null;
        }
    }

    @Override
    public void onError(@NonNull BroadcastException exception) {
        if (pendingJoinResult != null) {
            pendingJoinResult.error("native_error", exception.getMessage(), null);
            pendingJoinResult = null;
        }
        final Map<String, Object> event = typeOnly("error");
        event.put("code", -1);
        event.put("message", exception.getMessage() == null
                ? "Amazon IVS SDK reported an error."
                : exception.getMessage());
        emit(event);
    }

    @Override
    public void onParticipantJoined(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo) {
        emitParticipant("participantJoined", participantInfo);
    }

    @Override
    public void onParticipantLeft(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo) {
        if (!participantInfo.isLocal) {
            remoteVideoStreams.remove(participantInfo.userId);
            updateRemotePreviewHolders(participantInfo.userId, null);
        }
        emitParticipant("participantLeft", participantInfo);
    }

    @Override
    public void onParticipantPublishStateChanged(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull Stage.PublishState publishState) {}

    @Override
    public void onParticipantSubscribeStateChanged(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull Stage.SubscribeState subscribeState) {}

    @Override
    public void onParticipantMetadataUpdated(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo) {
        emitParticipant("participantJoined", participantInfo);
    }

    @Override
    public void onStreamsAdded(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull List<StageStream> streams) {
        for (StageStream stream : streams) {
            observeStream(stream);
            if (!participantInfo.isLocal && stream instanceof ImageStageStream) {
                final ImageStageStream imageStream = (ImageStageStream) stream;
                remoteVideoStreams.put(participantInfo.userId, imageStream);
                updateRemotePreviewHolders(participantInfo.userId, imageStream);
            }
            emitStreamAvailability(participantInfo, stream, true);
        }
    }

    @Override
    public void onStreamsRemoved(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull List<StageStream> streams) {
        for (StageStream stream : streams) {
            observedStreams.remove(stream);
            if (!participantInfo.isLocal && stream instanceof ImageStageStream) {
                remoteVideoStreams.remove(participantInfo.userId);
                updateRemotePreviewHolders(participantInfo.userId, null);
            }
            emitStreamAvailability(participantInfo, stream, false);
        }
    }

    @Override
    public void onStreamsMutedChanged(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull List<StageStream> streams) {
        for (StageStream stream : streams) {
            emitStreamAvailability(participantInfo, stream, true);
        }
    }

    @Override
    public void onStreamAdaptionChanged(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull RemoteStageStream stream,
            boolean hasAdaption) {}

    @Override
    public void onStreamLayersChanged(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull RemoteStageStream stream,
            @NonNull List<RemoteStageStream.Layer> layers) {}

    @Override
    public void onStreamLayerSelected(
            @NonNull Stage stage,
            @NonNull ParticipantInfo participantInfo,
            @NonNull RemoteStageStream stream,
            @Nullable RemoteStageStream.Layer layer,
            @NonNull RemoteStageStream.LayerSelectedReason reason) {}

    private static Map<String, Object> typeOnly(String type) {
        final Map<String, Object> event = new HashMap<>();
        event.put("type", type);
        return event;
    }

    private void attachPreview(FrameLayout holder, @Nullable ImagePreviewSurfaceView preview) {
        mainHandler.post(() -> {
            holder.removeAllViews();
            if (preview == null) return;
            final ViewGroup parent = preview.getParent() instanceof ViewGroup
                    ? (ViewGroup) preview.getParent()
                    : null;
            if (parent != null) parent.removeView(preview);
            holder.addView(
                    preview,
                    new FrameLayout.LayoutParams(
                            ViewGroup.LayoutParams.MATCH_PARENT,
                            ViewGroup.LayoutParams.MATCH_PARENT));
        });
    }

    private void updateLocalPreviewHolders(@Nullable ImageLocalStageStream stream) {
        final List<FrameLayout> holders = previewHolders.get(LOCAL_VIEW_KEY);
        if (holders == null) return;
        final ImagePreviewSurfaceView preview =
                stream == null ? null : stream.getPreviewSurfaceView();
        for (FrameLayout holder : new ArrayList<>(holders)) {
            attachPreview(holder, preview);
        }
    }

    private void updateRemotePreviewHolders(
            String key,
            @Nullable ImageStageStream stream) {
        final List<FrameLayout> holders = previewHolders.get(key);
        if (holders == null) return;
        final ImagePreviewSurfaceView preview =
                stream == null ? null : stream.getPreviewSurfaceView();
        for (FrameLayout holder : new ArrayList<>(holders)) {
            attachPreview(holder, preview);
        }
    }

    private void clearAllPreviewHolders() {
        mainHandler.post(() -> {
            for (List<FrameLayout> holders : previewHolders.values()) {
                for (FrameLayout holder : holders) holder.removeAllViews();
            }
        });
    }

    void attachPlatformView(FrameLayout holder, String userId, boolean isLocal) {
        final String key = isLocal ? LOCAL_VIEW_KEY : userId;
        previewHolders.computeIfAbsent(key, ignored -> new ArrayList<>()).add(holder);
        if (isLocal) {
            attachPreview(
                    holder,
                    cameraStream == null ? null : cameraStream.getPreviewSurfaceView());
        } else {
            final ImageStageStream remoteStream = remoteVideoStreams.get(userId);
            attachPreview(
                    holder,
                    remoteStream == null ? null : remoteStream.getPreviewSurfaceView());
        }
    }

    void detachPlatformView(FrameLayout holder, String userId, boolean isLocal) {
        final String key = isLocal ? LOCAL_VIEW_KEY : userId;
        final List<FrameLayout> holders = previewHolders.get(key);
        if (holders == null) return;
        holders.remove(holder);
        if (holders.isEmpty()) previewHolders.remove(key);
        holder.removeAllViews();
    }

    private static final class IvsVideoViewFactory extends PlatformViewFactory {
        private final FlutterRealtimeMediaIvsPlugin plugin;

        IvsVideoViewFactory(FlutterRealtimeMediaIvsPlugin plugin) {
            super(StandardMessageCodec.INSTANCE);
            this.plugin = plugin;
        }

        @Override
        public PlatformView create(
                Context context,
                int viewId,
                @Nullable Object args) {
            final Map<?, ?> params = args instanceof Map ? (Map<?, ?>) args : new HashMap<>();
            final String userId = String.valueOf(params.get("userId"));
            final boolean isLocal = Boolean.TRUE.equals(params.get("isLocal"));
            return new IvsVideoPlatformView(context, plugin, userId, isLocal);
        }
    }

    private static final class IvsVideoPlatformView implements PlatformView {
        private final FrameLayout holder;
        private final FlutterRealtimeMediaIvsPlugin plugin;
        private final String userId;
        private final boolean isLocal;

        IvsVideoPlatformView(
                Context context,
                FlutterRealtimeMediaIvsPlugin plugin,
                String userId,
                boolean isLocal) {
            this.holder = new FrameLayout(context);
            this.plugin = plugin;
            this.userId = userId;
            this.isLocal = isLocal;
            plugin.attachPlatformView(holder, userId, isLocal);
        }

        @Override
        public View getView() {
            return holder;
        }

        @Override
        public void dispose() {
            plugin.detachPlatformView(holder, userId, isLocal);
        }
    }
}
