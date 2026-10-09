import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'realtime_moderation.dart';

// ignore_for_file: prefer_initializing_formals

/// High-level owner for a standalone product-chat room.
class RealtimeChatRoom {
  RealtimeChatRoom({required this.room, required void Function() disposeClient})
    : _disposeClient = disposeClient;

  final ChatRoomSession room;
  final void Function() _disposeClient;
  Future<void>? _disposeFuture;
  Duration cleanupTimeout = const Duration(seconds: 10);

  ChatSession get session => room.session;
  String get roomCode => room.roomCode;
  String get providerId => session.providerId;
  RealtimeChatModeration get moderation =>
      RealtimeChatModeration(session, room.moderation);

  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    final cleanup = Cleanup(timeout: cleanupTimeout);
    await cleanup.run('chat.session', () async {
      await room.dispose();
    });
    await cleanup.run('chat.client', () async {
      _disposeClient();
    });
    cleanup.finish(domain: 'chat');
  }
}
