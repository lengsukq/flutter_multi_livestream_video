import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

enum ChatUiAction {
  send,
  delete,
  removeMember,
  muteMember,
  banMember,
  changeMemberRole,
  closeRoom,
  loadMembers,
}

/// Shared presentation state for both standalone and media-attached chat.
///
/// Owns subscriptions and transient UI state but never owns the ChatSession.
/// Only the session's producer handles networking, credentials and identity.
class ChatUiController extends ChangeNotifier {
  ChatUiController(this.session, {this.moderation}) {
    _messages = List.unmodifiable(session.messages);
    _state = session.state;
    _messageSubscription = session.messageSnapshots.listen((value) {
      if (_disposed) return;
      _messages = List.unmodifiable(value);
      notifyListeners();
    });
    _stateSubscription = session.states.listen((value) {
      if (_disposed) return;
      _state = value;
      notifyListeners();
    });
  }

  final ChatSession session;
  final ChatModeration? moderation;
  StreamSubscription<List<ChatMessage>>? _messageSubscription;
  StreamSubscription<ChatConnectionState>? _stateSubscription;
  List<ChatMessage> _messages = const [];
  ChatConnectionState _state = ChatConnectionState.disconnected;
  String _search = '';
  ChatMessage? _replyTo;
  Object? _error;
  List<ChatMember> _members = const [];
  final Set<ChatUiAction> _pending = {};
  bool _disposed = false;

  List<ChatMessage> get messages => _messages;
  ChatConnectionState get state => _state;
  String get search => _search;
  ChatMessage? get replyTo => _replyTo;
  Object? get error => _error;
  List<ChatMember> get members => _members;
  bool isPending(ChatUiAction action) => _pending.contains(action);
  bool get isHost => session.role == ChatRole.host;
  bool get canSend => _state.isConnected && session.capabilities.canSendMessage;
  ChatManagementCapabilities get managementCapabilities =>
      moderation is ChatModerationCapabilitySource
      ? (moderation! as ChatModerationCapabilitySource).moderationCapabilities
      : session.capabilities.managementCapabilities;

  List<ChatMessage> get filteredMessages {
    final term = _search.trim().toLowerCase();
    if (term.isEmpty) return _messages;
    return List.unmodifiable(
      _messages.where(
        (msg) =>
            msg.message.toLowerCase().contains(term) ||
            msg.userId.toLowerCase().contains(term) ||
            msg.displayName.toLowerCase().contains(term),
      ),
    );
  }

  void setSearch(String text) {
    if (_disposed || text == _search) return;
    _search = text;
    notifyListeners();
  }

  void selectReply(ChatMessage? message) {
    if (_disposed) return;
    _replyTo = message;
    notifyListeners();
  }

  Future<void> _run(ChatUiAction action, Future<void> Function() call) async {
    if (_disposed || _pending.contains(action)) return;
    _pending.add(action);
    _error = null;
    notifyListeners();
    try {
      await call();
    } catch (error) {
      if (!_disposed) _error = error;
      rethrow;
    } finally {
      if (!_disposed) {
        _pending.remove(action);
        notifyListeners();
      }
    }
  }

  Future<void> send(String raw) async {
    if (!canSend || raw.trim().isEmpty || isPending(ChatUiAction.send)) return;
    final reply = _replyTo;
    final text = raw.trim();
    final content = reply == null
        ? text
        : '「Reply to ${reply.displayName.isEmpty ? reply.userId : reply.displayName}: ${reply.message}」\n$text';
    await _run(ChatUiAction.send, () => session.sendMessage(content));
    if (!_disposed) selectReply(null);
  }

  Future<void> deleteMessage(ChatMessage message) async {
    if (!isHost &&
        (session is! ChatSessionIdentity ||
            message.userId != (session as ChatSessionIdentity).localUserId)) {
      return;
    }
    if (!managementCapabilities.deleteMessage.supported &&
        !managementCapabilities.recallMessage.supported) {
      return;
    }
    await _run(ChatUiAction.delete, () async {
      final governance = moderation;
      if (governance is ChatMessageDeleteAction) {
        await (governance as ChatMessageDeleteAction).deleteMessage(message.id);
      } else if (session.capabilities.canDeleteMessage) {
        await session.deleteMessage(message.id);
      } else if (governance != null) {
        await governance.recallMessage(message.id);
      } else {
        return;
      }
    });
  }

  Future<void> removeMember(String userId) async {
    if (!_canManageMember(userId) ||
        !managementCapabilities.removeMember.supported) {
      return;
    }
    await _run(ChatUiAction.removeMember, () async {
      if (moderation != null) {
        await moderation!.removeMember(userId);
      } else {
        await session.disconnectUser(userId);
      }
      await refreshMembers();
    });
  }

  bool _canManageMember(String userId) =>
      isHost &&
      (session is! ChatSessionIdentity ||
          (session as ChatSessionIdentity).localUserId != userId);

  Future<void> muteMember(String userId, {required bool muted}) async {
    if (!_canManageMember(userId) ||
        moderation == null ||
        !managementCapabilities.muteMember.supported) {
      return;
    }
    await _run(ChatUiAction.muteMember, () async {
      await moderation!.muteMember(userId, muted: muted);
      await refreshMembers();
    });
  }

  Future<void> banMember(String userId, {required bool banned}) async {
    if (!_canManageMember(userId) ||
        moderation == null ||
        !managementCapabilities.banMember.supported) {
      return;
    }
    await _run(ChatUiAction.banMember, () async {
      await moderation!.banMember(userId, banned: banned);
      await refreshMembers();
    });
  }

  Future<void> changeMemberRole(String userId, ChatRole role) async {
    if (!_canManageMember(userId) ||
        moderation == null ||
        !managementCapabilities.manageRoles.supported) {
      return;
    }
    await _run(ChatUiAction.changeMemberRole, () async {
      await moderation!.changeMemberRole(userId, role);
      await refreshMembers();
    });
  }

  Future<void> refreshMembers() async {
    if (moderation == null ||
        !isHost ||
        !managementCapabilities.listMembers.supported) {
      return;
    }
    await _run(ChatUiAction.loadMembers, () async {
      final members = await moderation!.listMembers();
      if (!_disposed) _members = List.unmodifiable(members);
    });
  }

  Future<void> closeRoom() async {
    if (moderation == null ||
        !isHost ||
        !managementCapabilities.closeRoom.supported) {
      return;
    }
    await _run(ChatUiAction.closeRoom, moderation!.closeRoom);
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_messageSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    super.dispose();
  }
}
