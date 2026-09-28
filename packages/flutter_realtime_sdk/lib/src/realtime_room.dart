import 'dart:async';

// ignore_for_file: prefer_initializing_formals

import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_chat_rtc/flutter_realtime_chat_rtc.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_error.dart';
import 'realtime_event.dart';
import 'realtime_room_state.dart';
import 'realtime_moderation.dart';

/// A fully resolved room containing media, rendering and optional chat.
class RealtimeRoom {
  RealtimeRoom({
    required this.media,
    required this.renderer,
    this.chat,
    ChatRoomSession? productChatRoom,
    RtcDataChatSession? rtcChatRoom,
    required void Function() disposeClients,
  }) : _productChatRoom = productChatRoom,
       _rtcChatRoom = rtcChatRoom,
       _disposeClients = disposeClients {
    _mediaEventSubscription = media.session.events.listen(_onMediaEvent);
    _mediaStateSubscription = media.session.states.listen((_) => _emitState());
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
  final MediaTrackRenderer renderer;
  final ChatSession? chat;
  final ChatRoomSession? _productChatRoom;
  final RtcDataChatSession? _rtcChatRoom;
  final void Function() _disposeClients;
  final StreamController<RealtimeEvent> _eventController =
      StreamController<RealtimeEvent>.broadcast();
  final StreamController<RealtimeRoomState> _stateController =
      StreamController<RealtimeRoomState>.broadcast();
  StreamSubscription<MediaEvent>? _mediaEventSubscription;
  StreamSubscription<MediaSessionState>? _mediaStateSubscription;
  StreamSubscription<MediaBackendError>? _backendErrorSubscription;
  StreamSubscription<ChatEvent>? _chatEventSubscription;
  StreamSubscription<ChatConnectionState>? _chatStateSubscription;
  bool _disposed = false;

  String get roomCode => media.roomCode;
  String get providerId => media.providerId;
  String? get chatProvider => media.chatProvider;
  RealtimeRoomCapabilities get capabilities => RealtimeRoomCapabilities(
    media: media.session.capabilities,
    chat: chat?.capabilities,
  );
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
    try {
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
            await media.dispose();
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
}
