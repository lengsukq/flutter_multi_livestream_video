import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'realtime_moderation.dart';

// ignore_for_file: prefer_initializing_formals

/// High-level owner for a standalone product-chat room.
class RealtimeChatRoom {
  RealtimeChatRoom({required this.room, required void Function() disposeClient})
    : _disposeClient = disposeClient;

  final ChatRoomSession room;
  final void Function() _disposeClient;
  bool _disposed = false;

  ChatSession get session => room.session;
  String get roomCode => room.roomCode;
  String get providerId => session.providerId;
  RealtimeChatModeration get moderation =>
      RealtimeChatModeration(session, room.moderation);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await room.dispose();
    _disposeClient();
  }
}
