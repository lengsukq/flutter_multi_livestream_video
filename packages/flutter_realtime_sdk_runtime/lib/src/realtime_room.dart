import 'room_video_effects_controller.dart';
import 'room_annotation_coordinator.dart';
import 'room_recording_controller.dart';
import 'package:flutter_realtime_live_core/flutter_realtime_live_core.dart';
import 'dart:async';

// ignore_for_file: prefer_initializing_formals

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_rtc/flutter_realtime_chat_rtc.dart';
import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_video_effects/flutter_realtime_video_effects.dart';

import 'realtime_error.dart';
import 'shared_content_controller.dart';
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
    this.classroom,
    this.liveInteractions,
    ChatRoomSession? productChatRoom,
    RtcDataChatSession? rtcChatRoom,
    required void Function() disposeClients,
    VideoEffectsBridge? videoEffectsBridge,
    MediaBackgroundCapabilities effectsCapabilities =
        const MediaBackgroundCapabilities.none(),
  }) : publicProviderId = publicProviderId ?? media.providerId,
       _productChatRoom = productChatRoom,
       _rtcChatRoom = rtcChatRoom,
       _disposeClients = disposeClients {
    _effects = RoomVideoEffectsController(
      media: media,
      effectsCapabilities: effectsCapabilities,
      providerId: providerId,
      bridge: videoEffectsBridge,
      onFailure: _reportFailure,
    );
    recording = RoomRecordingController(
      media: media,
      providerId: providerId,
      onFailure: _reportFailure,
    );
    _mediaEventSubscription = media.session.events.listen(_onMediaEvent);
    _mediaStateSubscription = media.session.states.listen(_onMediaState);
    if (classroom != null) {
      sharedContent = SharedContentController(
        media: media.session,
        classroom: classroom!,
      );
      _annotations = RoomAnnotationCoordinator(
        media.session,
        classroom!,
        _reportFailure,
      );
    }
    _backendErrorSubscription = media.backendErrors.listen((error) {
      if (_disposed) return;
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

  /// Optional provider-neutral classroom SDK. Null for live/direct rooms.
  final ClassroomSession? classroom;
  SharedContentController? sharedContent;
  final LiveInteractionSession? liveInteractions;
  final ChatRoomSession? _productChatRoom;
  final RtcDataChatSession? _rtcChatRoom;
  final void Function() _disposeClients;
  final StreamController<RealtimeEvent> _eventController =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<RealtimeRoomState> _stateController =
      StreamController<RealtimeRoomState>.broadcast();
  StreamSubscription<MediaEvent>? _mediaEventSubscription;
  StreamSubscription<MediaSessionState>? _mediaStateSubscription;
  StreamSubscription<RealtimeException>? _backendErrorSubscription;
  StreamSubscription<ChatEvent>? _chatEventSubscription;
  StreamSubscription<ChatConnectionState>? _chatStateSubscription;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);
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
  late final RoomVideoEffectsController _effects;
  RoomAnnotationCoordinator? _annotations;
  @override
  MediaBackgroundCapabilities get backgroundCapabilities =>
      _effects.backgroundCapabilities;
  @override
  MediaBackgroundEffect get backgroundEffect => _effects.backgroundEffect;
  Future<void> prepareVideoEffects(MediaLocalPreviewSettings settings) =>
      _effects.prepareVideoEffects(settings);
  @override
  Future<void> setBackgroundEffect(MediaBackgroundEffect effect) =>
      _effects.setBackgroundEffect(effect);

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

  /// Recording controller for this room session.
  late final RoomRecordingController recording;
  MediaRecordingController get recordingController => recording;

  /// Current recording status of the room.
  RecordingStatus get recordingStatus => recording.status;

  /// Emits recording status changes.
  Stream<RecordingStatus> get recordingStatuses => recording.statuses;

  /// Emits recorded duration updates every second.
  Stream<Duration> get recordingDurations => recording.durations;

  /// Starts recording with optional [options].
  ///
  /// Defaults to [RecordingMode.local] (writing directly to local sandbox storage).
  Future<RecordingResult> startRecording([RecordingOptions? options]) =>
      recording.startRecording(options);

  /// Stops the active recording session and finishes writing files.
  Future<RecordingResult?> stopRecording() => recording.stopRecording();

  /// Generates a structured [CloudRecordingDescriptor] containing official
  /// vendor API endpoints, HTTP headers, and request body payloads.
  CloudRecordingDescriptor describeCloudRecording([
    RecordingOptions? options,
  ]) => recording.describeCloudRecording(options);

  void _onMediaState(MediaSessionState state) {
    _emitState();
    if (_disposed ||
        (state != MediaSessionState.ended &&
            state != MediaSessionState.failed &&
            state != MediaSessionState.disposed)) {
      return;
    }
    unawaited(
      _effects.release().catchError((Object error, StackTrace stack) {
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

  void _reportFailure(RealtimeException error) {
    if (!_disposed) _eventController.add(RealtimeBackendFailure(error));
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

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    _effects.beginDisposal();
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('annotation.coordinator', () async {
      await _annotations?.dispose();
    });
    await cleanup.run('recording', recording.dispose);
    await cleanup.run('video.effects', _effects.dispose);
    await cleanup.run('sharedContent', () async {
      await sharedContent?.dispose();
    });
    await cleanup.run('classroom', () async {
      await classroom?.dispose();
    });
    await cleanup.run('liveInteractions', () async {
      await liveInteractions?.dispose();
    });
    await cleanup.run('media.events', () async {
      await _mediaEventSubscription?.cancel();
    });
    await cleanup.run('media.states', () async {
      await _mediaStateSubscription?.cancel();
    });
    await cleanup.run('backend.errors', () async {
      await _backendErrorSubscription?.cancel();
    });
    await cleanup.run('chat.events', () async {
      await _chatEventSubscription?.cancel();
    });
    await cleanup.run('chat.states', () async {
      await _chatStateSubscription?.cancel();
    });
    await cleanup.run('chat.product', () async {
      await _productChatRoom?.dispose();
    });
    await cleanup.run('chat.rtc', () async {
      await _rtcChatRoom?.dispose();
    });
    await cleanup.run('media', () async {
      await media.dispose();
    });
    await cleanup.run('states', () async {
      await _stateController.close();
    });
    await cleanup.run('events', () async {
      await _eventController.close();
    });
    await cleanup.run('clients', () async {
      _disposeClients();
    });
    cleanup.finish(domain: 'room');
  }
}
