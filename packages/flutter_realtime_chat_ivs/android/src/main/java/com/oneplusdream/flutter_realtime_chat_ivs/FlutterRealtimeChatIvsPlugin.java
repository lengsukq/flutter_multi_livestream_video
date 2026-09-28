package com.oneplusdream.flutter_realtime_chat_ivs;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.amazonaws.ivs.chat.messaging.ChatRoom;
import com.amazonaws.ivs.chat.messaging.ChatRoomListener;
import com.amazonaws.ivs.chat.messaging.ChatToken;
import com.amazonaws.ivs.chat.messaging.ChatTokenCallback;
import com.amazonaws.ivs.chat.messaging.DisconnectReason;
import com.amazonaws.ivs.chat.messaging.RequestCallback;
import com.amazonaws.ivs.chat.messaging.entities.ChatError;
import com.amazonaws.ivs.chat.messaging.entities.ChatEvent;
import com.amazonaws.ivs.chat.messaging.entities.ChatMessage;
import com.amazonaws.ivs.chat.messaging.entities.DeleteMessageEvent;
import com.amazonaws.ivs.chat.messaging.entities.DisconnectUserEvent;
import com.amazonaws.ivs.chat.messaging.requests.DeleteMessageRequest;
import com.amazonaws.ivs.chat.messaging.requests.DisconnectUserRequest;
import com.amazonaws.ivs.chat.messaging.requests.SendMessageRequest;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import kotlin.Unit;

public final class FlutterRealtimeChatIvsPlugin
        implements FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private static final String METHOD_CHANNEL =
            "com.oneplusdream.flutter_realtime_chat_ivs/methods";
    private static final String EVENT_CHANNEL =
            "com.oneplusdream.flutter_realtime_chat_ivs/events";

    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;
    private ChatRoom room;
    private ChatToken initialToken;
    private boolean initialTokenAvailable;
    private boolean connectedOnce;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        disposeRoom();
        if (methodChannel != null) methodChannel.setMethodCallHandler(null);
        if (eventChannel != null) eventChannel.setStreamHandler(null);
        methodChannel = null;
        eventChannel = null;
        eventSink = null;
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
                case "connect":
                    connect(call, result);
                    return;
                case "sendMessage":
                    sendMessage(requireString(call, "message"), result);
                    return;
                case "deleteMessage":
                    deleteMessage(requireString(call, "messageId"), result);
                    return;
                case "disconnectUser":
                    disconnectUser(requireString(call, "userId"), result);
                    return;
                case "disconnect":
                    disconnectRoom();
                    result.success(null);
                    return;
                case "dispose":
                    disposeRoom();
                    result.success(null);
                    return;
                default:
                    result.notImplemented();
            }
        } catch (IllegalArgumentException error) {
            result.error("invalid_argument", error.getMessage(), null);
        } catch (IllegalStateException error) {
            result.error("invalid_state", error.getMessage(), null);
        } catch (Exception error) {
            result.error("native_error", error.getMessage(), error.toString());
        }
    }

    private void connect(MethodCall call, MethodChannel.Result result) {
        if (room != null) {
            throw new IllegalStateException("An Amazon IVS Chat room is already active.");
        }
        final String region = requireString(call, "region");
        initialToken = tokenFromArguments(call.arguments);
        initialTokenAvailable = true;
        connectedOnce = false;

        room = new ChatRoom(
                region,
                callback -> {
                    provideToken(callback);
                    return Unit.INSTANCE;
                });
        room.setListener(new ChatRoomListener() {
            @Override
            public void onConnecting(@NonNull ChatRoom chatRoom) {
                emit(mapOf(
                        "type", "connecting",
                        "reconnecting", connectedOnce));
            }

            @Override
            public void onConnected(@NonNull ChatRoom chatRoom) {
                connectedOnce = true;
                emit(mapOf("type", "connected"));
            }

            @Override
            public void onDisconnected(
                    @NonNull ChatRoom chatRoom,
                    @NonNull DisconnectReason reason) {
                emit(mapOf(
                        "type", "disconnected",
                        "reason", disconnectReason(reason)));
            }

            @Override
            public void onMessageReceived(
                    @NonNull ChatRoom chatRoom,
                    @NonNull ChatMessage message) {
                emit(messageEvent(message));
            }

            @Override
            public void onEventReceived(
                    @NonNull ChatRoom chatRoom,
                    @NonNull ChatEvent event) {
                // Generic custom events are intentionally not part of P0 Chat Core.
            }

            @Override
            public void onMessageDeleted(
                    @NonNull ChatRoom chatRoom,
                    @NonNull DeleteMessageEvent event) {
                emit(mapOf(
                        "type", "messageDeleted",
                        "messageId", event.getMessageId()));
            }

            @Override
            public void onUserDisconnected(
                    @NonNull ChatRoom chatRoom,
                    @NonNull DisconnectUserEvent event) {
                emit(mapOf(
                        "type", "userDisconnected",
                        "userId", event.getUserId()));
            }
        });
        room.connect();
        result.success(null);
    }

    private void provideToken(ChatTokenCallback callback) {
        if (initialTokenAvailable && initialToken != null) {
            final ChatToken token = initialToken;
            initialToken = null;
            initialTokenAvailable = false;
            callback.onSuccess(token);
            return;
        }
        final MethodChannel channel = methodChannel;
        if (channel == null) {
            callback.onFailure(new IllegalStateException("Flutter bridge is detached."));
            return;
        }
        mainHandler.post(() -> channel.invokeMethod(
                "requestToken",
                null,
                new MethodChannel.Result() {
                    @Override
                    public void success(Object result) {
                        try {
                            callback.onSuccess(tokenFromArguments(result));
                        } catch (Exception error) {
                            callback.onFailure(error);
                        }
                    }

                    @Override
                    public void error(String code, String message, Object details) {
                        callback.onFailure(
                                new IllegalStateException(
                                        message == null
                                                ? "Unable to refresh IVS Chat token."
                                                : message));
                    }

                    @Override
                    public void notImplemented() {
                        callback.onFailure(
                                new IllegalStateException(
                                        "IVS Chat token provider is unavailable."));
                    }
                }));
    }

    private void sendMessage(String message, MethodChannel.Result result) {
        final ChatRoom active = requireRoom();
        final SendMessageRequest request = new SendMessageRequest(message);
        active.sendMessage(
                request,
                new RequestCallback<SendMessageRequest, ChatMessage>() {
                    @Override
                    public void onConfirmed(
                            @NonNull SendMessageRequest confirmedRequest,
                            @NonNull ChatMessage response) {
                        mainHandler.post(() -> result.success(null));
                    }

                    @Override
                    public void onRejected(
                            @NonNull SendMessageRequest rejectedRequest,
                            @NonNull ChatError error) {
                        reject(result, error);
                    }
                });
    }

    private void deleteMessage(String messageId, MethodChannel.Result result) {
        final ChatRoom active = requireRoom();
        final DeleteMessageRequest request = new DeleteMessageRequest(messageId);
        active.deleteMessage(
                request,
                new RequestCallback<DeleteMessageRequest, DeleteMessageEvent>() {
                    @Override
                    public void onConfirmed(
                            @NonNull DeleteMessageRequest confirmedRequest,
                            @NonNull DeleteMessageEvent response) {
                        mainHandler.post(() -> result.success(null));
                    }

                    @Override
                    public void onRejected(
                            @NonNull DeleteMessageRequest rejectedRequest,
                            @NonNull ChatError error) {
                        reject(result, error);
                    }
                });
    }

    private void disconnectUser(String userId, MethodChannel.Result result) {
        final ChatRoom active = requireRoom();
        final DisconnectUserRequest request = new DisconnectUserRequest(userId);
        active.disconnectUser(
                request,
                new RequestCallback<DisconnectUserRequest, DisconnectUserEvent>() {
                    @Override
                    public void onConfirmed(
                            @NonNull DisconnectUserRequest confirmedRequest,
                            @NonNull DisconnectUserEvent response) {
                        mainHandler.post(() -> result.success(null));
                    }

                    @Override
                    public void onRejected(
                            @NonNull DisconnectUserRequest rejectedRequest,
                            @NonNull ChatError error) {
                        reject(result, error);
                    }
                });
    }

    private void reject(MethodChannel.Result result, ChatError error) {
        final int code = error.getErrorCode();
        final String platformCode =
                code == 401 ? "unauthorized" : code == 403 ? "forbidden" : "native_error";
        mainHandler.post(() -> result.error(
                platformCode,
                error.getErrorMessage(),
                mapOf(
                        "errorCode", code,
                        "id", error.getId(),
                        "requestId", error.getRequestId())));
    }

    private void disconnectRoom() {
        if (room == null) return;
        room.disconnect();
        initialToken = null;
        initialTokenAvailable = false;
    }

    private void disposeRoom() {
        if (room != null) {
            room.disconnect();
            room.setListener(null);
        }
        room = null;
        initialToken = null;
        initialTokenAvailable = false;
        connectedOnce = false;
    }

    private ChatRoom requireRoom() {
        if (room == null) {
            throw new IllegalStateException("No active Amazon IVS Chat room.");
        }
        return room;
    }

    private static ChatToken tokenFromArguments(Object raw) {
        if (!(raw instanceof Map)) {
            throw new IllegalArgumentException("IVS Chat token payload is required.");
        }
        final Map<?, ?> map = (Map<?, ?>) raw;
        final String token = requiredMapString(map, "token");
        final long sessionExpiration = requiredTimestamp(
                map,
                "sessionExpirationTimeMs");
        final long tokenExpiration = requiredTimestamp(
                map,
                "tokenExpirationTimeMs");
        return new ChatToken(
                token,
                new Date(sessionExpiration),
                new Date(tokenExpiration));
    }

    private static String requiredMapString(Map<?, ?> map, String key) {
        final Object raw = map.get(key);
        final String value = raw == null ? "" : raw.toString().trim();
        if (value.isEmpty()) {
            throw new IllegalArgumentException(key + " is required.");
        }
        return value;
    }

    private static long requiredTimestamp(Map<?, ?> map, String key) {
        final Object raw = map.get(key);
        if (raw instanceof Number) return ((Number) raw).longValue();
        try {
            return Long.parseLong(raw == null ? "" : raw.toString());
        } catch (NumberFormatException error) {
            throw new IllegalArgumentException(key + " must be a Unix timestamp.");
        }
    }

    private static String requireString(MethodCall call, String key) {
        final Object raw = call.argument(key);
        final String value = raw == null ? "" : raw.toString().trim();
        if (value.isEmpty()) {
            throw new IllegalArgumentException(key + " is required.");
        }
        return value;
    }

    private Map<String, Object> messageEvent(ChatMessage message) {
        final Map<String, Object> value = new HashMap<>();
        value.put("type", "message");
        value.put("id", message.getId());
        value.put("userId", message.getSender().getUserId());
        value.put("message", message.getContent());
        value.put("timestampMs", message.getSendTime().getTime());
        final Map<String, String> messageAttributes = message.getAttributes();
        final Map<String, String> senderAttributes = message.getSender().getAttributes();
        final Map<String, String> attributes = new HashMap<>();
        if (messageAttributes != null) attributes.putAll(messageAttributes);
        if (senderAttributes != null) {
            for (Map.Entry<String, String> entry : senderAttributes.entrySet()) {
                attributes.putIfAbsent(entry.getKey(), entry.getValue());
            }
        }
        value.put("attributes", attributes);
        value.put(
                "displayName",
                attributes.getOrDefault("displayName", message.getSender().getUserId()));
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

    private static String disconnectReason(DisconnectReason reason) {
        final String raw = reason.name();
        return "CLIENT_DISCONNECT".equals(raw)
                ? "clientDisconnect"
                : raw.toLowerCase();
    }

    private static Map<String, Object> mapOf(Object... values) {
        final Map<String, Object> map = new HashMap<>();
        for (int index = 0; index + 1 < values.length; index += 2) {
            if (values[index + 1] != null) {
                map.put(String.valueOf(values[index]), values[index + 1]);
            }
        }
        return map;
    }
}
