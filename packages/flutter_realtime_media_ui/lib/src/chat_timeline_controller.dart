import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

/// Tracks message identity across bounded snapshots rather than list length.
class ChatTimelineController {
  final Set<String> _seen = {};
  void seed(List<ChatMessage> messages) {
    _seen
      ..clear()
      ..addAll(messages.map((m) => m.id));
  }

  int accept(List<ChatMessage> messages, bool Function(ChatMessage) isOwn) {
    final added = messages
        .where((m) => !_seen.contains(m.id) && !isOwn(m))
        .length;
    seed(messages);
    return added;
  }
}
