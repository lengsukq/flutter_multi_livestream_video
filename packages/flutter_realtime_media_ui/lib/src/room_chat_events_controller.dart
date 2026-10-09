import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'chat_timeline_controller.dart';

/// Owns room-attached Chat snapshot subscriptions, unread count and danmaku.
///
/// The media renderer never depends on these changes. Only the Chat/controls
/// view regions receive revisions when a relevant message changes.
class RoomChatEventsController {
  final danmaku = ValueNotifier<List<ChatMessage>>(const []);
  final _timeline = ChatTimelineController();
  StreamSubscription<List<ChatMessage>>? _subscription;
  int _generation = 0;
  int unread = 0;
  bool _disposed = false;

  void bind(
    ChatSession? session, {
    required bool Function() isChatOpen,
    required bool Function(ChatSession chat, ChatMessage message) isOwn,
    required VoidCallback onUnread,
  }) {
    if (_disposed) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    final initial = session?.messages ?? const <ChatMessage>[];
    danmaku.value = List.unmodifiable(initial);
    _timeline.seed(initial);
    unread = 0;
    if (session == null) return;

    _subscription = session.messageSnapshots.listen((messages) {
      if (_disposed || generation != _generation) return;
      danmaku.value = List.unmodifiable(messages);
      final added = _timeline.accept(messages, (m) => isOwn(session, m));
      if (!isChatOpen() && added > 0) {
        unread += added;
        onUnread();
      }
    });
  }

  void markRead() => unread = 0;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    danmaku.dispose();
  }
}
