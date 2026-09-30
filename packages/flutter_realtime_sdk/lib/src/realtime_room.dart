import 'dart:async';

// ignore_for_file: prefer_initializing_formals

import 'package:flutter/services.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_rtc/flutter_realtime_chat_rtc.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';

import 'realtime_error.dart';
import 'realtime_event.dart';
import 'realtime_room_state.dart';
import 'realtime_moderation.dart';

/// A fully resolved room containing media, rendering and optional chat.
class RealtimeRoom implements MediaBackgroundEffectsController {
  RealtimeRoom({
    required this.media,
    String? publicProviderId,
    required this.renderer,
    this.chat,
    ChatRoomSession? productChatRoom,
    RtcDataChatSession? rtcChatRoom,
    required void Function() disposeClients,
    VideoEffectsBridge? videoEffectsBridge,
  }) : publicProviderId = publicProviderId ?? media.providerId,
       _productChatRoom = productChatRoom,
       _rtcChatRoom = rtcChatRoom,
       _disposeClients = disposeClients,
       _videoEffectsBridge = videoEffectsBridge ?? VideoEffectsBridge() {
    _videoEffectsErrorSubscription = _videoEffectsBridge.failures.listen((
      failure,
    ) {
      if (_disposed || failure.sourceId != _processedVideoSource?.id) return;
      _eventController.add(
        RealtimeBackendFailure(
          mapRealtimeException(
            MediaError(
              code: MediaErrorCode.nativeError,
              message: failure.message,
              providerId: providerId,
            ),
            providerId: providerId,
          ),
        ),
      );
    });
    _mediaEventSubscription = media.session.events.listen(_onMediaEvent);
    _mediaStateSubscription = media.session.states.listen(_onMediaState);
    _backendErrorSubscription = media.backendErrors.listen((error) {
      _eventController.add(
        RealtimeBackendFailure(
          mapRealtimeException(error, providerId: providerId),
        ),
      );
    });
    final chatSession = chat;
    if (chatSession != null) {
      _chatEventSubscription = chatSession.events.listen(_onChatEvent);
      _chatStateSubscription = chatSession.states.listen((_) => _emitState());
    }
  }

  final MediaRoomSession media;
  final String publicProviderId;
  final MediaTrackRenderer renderer;
  final ChatSession? chat;
  final ChatRoomSession? _productChatRoom;
  final RtcDataChatSession? _rtcChatRoom;
  final void Function() _disposeClients;
  final StreamController<RealtimeEvent> _eventController =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<RealtimeRoomState> _stateController =
      StreamController<RealtimeRoomState>.broadcast();
  StreamSubscription<VideoEffectsFailure>? _videoEffectsErrorSubscription;
  StreamSubscription<MediaEvent>? _mediaEventSubscription;
  StreamSubscription<MediaSessionState>? _mediaStateSubscription;
  StreamSubscription<MediaBackendError>? _backendErrorSubscription;
  StreamSubscription<ChatEvent>? _chatEventSubscription;
  StreamSubscription<ChatConnectionState>? _chatStateSubscription;
  bool _disposed = false;
  final VideoEffectsBridge _videoEffectsBridge;
  Future<void> _videoOperation = Future<void>.value();
  ProcessedVideoSource? _processedVideoSource;
  MediaBackgroundEffect _processedBackgroundEffect =
      const MediaBackgroundEffect.none();

  String get roomCode => media.roomCode;
  String get providerId => publicProviderId;
  String get engineProviderId => media.providerId;
  String? get chatProvider => media.chatProvider;
  bool get usesProductChat => _productChatRoom != null;
  bool get usesRtcDataChat => _rtcChatRoom != null;
  RealtimeRoomCapabilities get capabilities => RealtimeRoomCapabilities(
    media: media.session.capabilities,
    chat: chat?.capabilities,
  );
  @override
  MediaBackgroundCapabilities get backgroundCapabilities {
    final active = media.session;
    if (active is ProcessedVideoSink) {
      return MediaBackgroundCapabilities(
        canBlur: active.capabilities.canBlurBackground,
        canReplaceImage: active.capabilities.canReplaceBackgroundImage,
      );
    }
    return media.backgroundCapabilities;
  }

  @override
  MediaBackgroundEffect get backgroundEffect => _processedVideoSource != null
      ? _processedBackgroundEffect
      : media.backgroundEffect;

  Future<void> prepareVideoEffects(MediaLocalPreviewSettings settings) =>
      _serializeVideoOperation(() => _prepareVideoEffects(settings));

  Future<void> _prepareVideoEffects(MediaLocalPreviewSettings settings) async {
    if (_disposed) {
      throw MediaError(
        code: MediaErrorCode.invalidState,
        message: 'The room has been disposed.',
        providerId: providerId,
      );
    }
    final active = media.session;
    if (!active.capabilities.canPublishVideo) {
      if (settings.backgroundEffect.enabled) _unsupportedBackground();
      return;
    }
    if (active is! ProcessedVideoSink) {
      if (settings.backgroundEffect.enabled) {
        await media.setBackgroundEffect(settings.backgroundEffect);
      }
      return;
    }
    final sink = active as ProcessedVideoSink;
    if (!backgroundCapabilities.supports(settings.backgroundEffect)) {
      _unsupportedBackground();
    }
    // Platforms reserved for future bridges retain their normal camera path
    // when effects are off. They must never advertise an enabled effect.
    if (!backgroundCapabilities.isSupported ||
        !await _supportsEffectsRuntime()) {
      if (settings.backgroundEffect.enabled) _unsupportedBackground();
      return;
    }

    var source = _processedVideoSource;
    if (source == null) {
      source = await _videoEffectsBridge.createSource(
        config: VideoEffectsSourceConfig(
          cameraDeviceId: settings.camera?.id,
          effect: settings.backgroundEffect,
        ),
      );
      if (_disposed) {
        await _videoEffectsBridge.disposeSource(source);
        throw MediaError(
          code: MediaErrorCode.invalidState,
          providerId: providerId,
          message: 'The room has been disposed.',
        );
      }
      if (!sink.supportsProcessedVideoSource(source)) {
        await _videoEffectsBridge.disposeSource(source);
        if (settings.backgroundEffect.enabled) _unsupportedBackground();
        return;
      }
      try {
        // Bind while muted so a disabled camera cannot briefly publish frames.
        await _videoEffectsBridge.setEnabled(source, false);
        await sink.attachProcessedVideoSource(source);
      } catch (error) {
        try {
          await sink.detachProcessedVideoSource();
        } finally {
          await _videoEffectsBridge.disposeSource(source);
        }
        if (_isUnavailableBridge(error)) {
          if (!settings.backgroundEffect.enabled) return;
          _unsupportedBackground();
        }
        rethrow;
      }
      _processedVideoSource = source;
    } else {
      if (settings.camera != null) {
        await _videoEffectsBridge.selectCamera(source, settings.camera!.id);
      }
      await _videoEffectsBridge.setEffect(source, settings.backgroundEffect);
    }
    await _videoEffectsBridge.setEnabled(source, settings.cameraEnabled);
    _processedBackgroundEffect = settings.backgroundEffect;
  }

  Future<bool> _supportsEffectsRuntime() async {
    try {
      return await _videoEffectsBridge.isSupported();
    } catch (error) {
      if (_isUnavailableBridge(error)) return false;
      rethrow;
    }
  }

  bool _isUnavailableBridge(Object error) =>
      error is MissingPluginException ||
      (error is MediaError &&
          error.code == MediaErrorCode.unsupportedFeature) ||
      (error is PlatformException &&
          (error.code.toLowerCase().contains('unsupported') ||
              error.code == 'not_implemented'));

  Never _unsupportedBackground() => throw MediaError(
    code: MediaErrorCode.unsupportedFeature,
    message:
        'The active provider cannot publish this background effect '
        'on this platform.',
    providerId: media.providerId,
  );

  Future<void> _serializeVideoOperation(Future<void> Function() action) {
    final operation = _videoOperation.then((_) async {
      try {
        await action();
      } on MissingPluginException catch (error) {
        throw MediaError(
          code: MediaErrorCode.unsupportedFeature,
          providerId: providerId,
          message: 'The video-effects bridge is unavailable.',
          details: error,
        );
      } on PlatformException catch (error) {
        final code = error.code.toLowerCase();
        throw MediaError(
          code: _isUnavailableBridge(error)
              ? MediaErrorCode.unsupportedFeature
              : code.contains('invalid')
              ? MediaErrorCode.invalidArgument
              : code.contains('permission') || code.contains('denied')
              ? MediaErrorCode.permissionDenied
              : MediaErrorCode.nativeError,
          providerId: providerId,
          message: error.message ?? 'Video processing failed.',
          details: error,
        );
      }
    });
    _videoOperation = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  @override
  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) =>
      _serializeVideoOperation(() async {
        if (media.session is ProcessedVideoSink) {
          await _prepareVideoEffects(
            MediaLocalPreviewSettings(
              cameraEnabled: media.session.snapshot.localVideoEnabled,
              backgroundEffect: effect,
            ),
          );
          return;
        }
        await media.setBackgroundEffect(effect);
      });

  List<MediaParticipant> get participants =>
      List.unmodifiable(media.snapshot.participants);
  RealtimeRoomState get state => RealtimeRoomState(
    media: media.session.state,
    chat: chat?.state,
    participants: participants,
    capabilities: capabilities,
  );
  Stream<RealtimeRoomState> get states => _stateController.stream;
  Stream<RealtimeEvent> get events => _eventController.stream;
  RealtimeMediaModeration get mediaModeration => RealtimeMediaModeration(media);
  RealtimeChatModeration? get chatModeration => chat == null
      ? null
      : RealtimeChatModeration(chat!, _productChatRoom?.moderation);

  void _onMediaState(MediaSessionState state) {
    _emitState();
    if (_disposed ||
        (state != MediaSessionState.ended &&
            state != MediaSessionState.failed &&
            state != MediaSessionState.disposed)) {
      return;
    }
    unawaited(
      _serializeVideoOperation(_disposeProcessedVideoSource).catchError((
        Object error,
        StackTrace stack,
      ) {
        if (!_disposed) {
          _eventController.add(
            RealtimeBackendFailure(
              mapRealtimeException(error, providerId: providerId),
            ),
          );
        }
      }),
    );
  }

  void _onMediaEvent(MediaEvent event) {
    if (_disposed) return;
    _eventController.add(RealtimeMediaEvent(event));
    _emitState();
  }

  void _onChatEvent(ChatEvent event) {
    if (_disposed) return;
    _eventController.add(RealtimeChatEvent(event));
    _emitState();
  }

  void _emitState() {
    if (_disposed) return;
    final value = state;
    _stateController.add(value);
    _eventController.add(RealtimeStateChanged(value));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _videoOperation;
    try {
      await _videoEffectsErrorSubscription?.cancel();
      await _mediaEventSubscription?.cancel();
      await _mediaStateSubscription?.cancel();
      await _backendErrorSubscription?.cancel();
      await _chatEventSubscription?.cancel();
      await _chatStateSubscription?.cancel();
      try {
        try {
          await _productChatRoom?.dispose();
        } finally {
          try {
            await _rtcChatRoom?.dispose();
          } finally {
            try {
              await _disposeProcessedVideoSource();
            } finally {
              await media.dispose();
            }
          }
        }
      } finally {
        await _stateController.close();
        await _eventController.close();
      }
    } finally {
      _disposeClients();
    }
  }

  Future<void> _disposeProcessedVideoSource() async {
    final source = _processedVideoSource;
    _processedVideoSource = null;
    if (source == null) return;
    final active = media.session;
    try {
      final ProcessedVideoSink? sink = active is ProcessedVideoSink
          ? active as ProcessedVideoSink
          : null;
      if (sink != null) {
        await sink.detachProcessedVideoSource();
      }
    } finally {
      await _videoEffectsBridge.disposeSource(source);
      _processedBackgroundEffect = const MediaBackgroundEffect.none();
    }
  }
}
