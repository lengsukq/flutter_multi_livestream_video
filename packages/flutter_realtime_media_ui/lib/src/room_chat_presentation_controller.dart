import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

/// Owns the draft and scroll position independently of room layouts.
/// Closing a side panel does not erase its draft or create new Chat subscriptions.
class RoomChatPresentationController extends ChangeNotifier {
  RoomChatPresentationController({required this.onError, this.onSent});
  final ValueChanged<RealtimeException> onError;
  final VoidCallback? onSent;
  final message = TextEditingController();
  final scroll = ScrollController();
  final _visibleIds = <String>{};
  bool _initialized = false;
  bool _disposed = false;
  bool sending = false;
  bool hasNewMessages = false;
  int _generation = 0;
  void reset() {
    ++_generation;
    message.clear();
    _visibleIds.clear();
    _initialized = false;
    sending = false;
    hasNewMessages = false;
  }

  void opened() {
    hasNewMessages = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  void revealLatest() {
    if (scroll.hasClients) scroll.jumpTo(0);
    hasNewMessages = false;
    notifyListeners();
  }

  void syncMessages(List<ChatMessage> messages) {
    final first = !_initialized;
    final added = messages.any((m) => !_visibleIds.contains(m.id));
    _initialized = true;
    _visibleIds
      ..clear()
      ..addAll(messages.map((m) => m.id));
    if (!first && !added) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !scroll.hasClients) return;
      if (first || scroll.position.pixels <= 72) {
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else {
        hasNewMessages = true;
        notifyListeners();
      }
    });
  }

  Future<void> send(ChatSession chat) async {
    final text = message.text.trim();
    if (_disposed || sending || text.isEmpty) return;
    final generation = _generation;
    sending = true;
    notifyListeners();
    try {
      await chat.sendMessage(text);
      if (_disposed || generation != _generation) return;
      message.clear();
      opened();
      onSent?.call();
    } catch (error, stack) {
      onError(
        normalizeRealtimeException(
          error,
          domain: 'chat.ui',
          operation: 'send',
          stackTrace: stack,
        ),
      );
    } finally {
      if (!_disposed && generation == _generation) {
        sending = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    message.dispose();
    scroll.dispose();
    super.dispose();
  }
}

bool isOwnRoomChatMessage(
  ChatSession chat,
  ChatMessage message,
  String participantId,
) {
  if (chat is ChatSessionIdentity) {
    final identity = chat as ChatSessionIdentity;
    final localUserId = identity.localUserId.trim();
    if (localUserId.isNotEmpty && message.userId == localUserId) return true;
    final localParticipantId = identity.localParticipantId.trim();
    if (localParticipantId.isNotEmpty &&
        message.attributes['participantId'] == localParticipantId) {
      return true;
    }
  }
  if (message.attributes['local'] == 'true') return true;
  return message.userId == participantId;
}
