import 'dart:collection';

import '../model/chat_error.dart';

typedef WebChatTokenProvider<T> = Future<T> Function();

/// Provider boundary used by Web chat adapters.
///
/// Drivers translate this small lifecycle into their vendor SDK. Session state,
/// callback lifetime, common error mapping, and duplicate event suppression are
/// handled by [WebChatRuntime].
abstract interface class WebChatDriver<T> {
  Future<void> connect(
    T credentials,
    WebChatDriverEvents events, {
    WebChatTokenProvider<T>? tokenProvider,
  });

  Future<void> sendMessage(String message);
  Future<void> deleteMessage(String messageId);
  Future<void> disconnectUser(String userId);
  Future<void> disconnect();
  Future<void> dispose();
}

class WebChatDriverEvents {
  const WebChatDriverEvents({
    this.onConnecting,
    this.onConnected,
    this.onDisconnected,
    this.onMessage,
    this.onMessageDeleted,
    this.onUserDisconnected,
    this.onError,
  });

  final void Function(bool reconnecting)? onConnecting;
  final void Function()? onConnected;
  final void Function(String reason)? onDisconnected;
  final void Function(Map<String, Object?> message)? onMessage;
  final void Function(String messageId)? onMessageDeleted;
  final void Function(String userId)? onUserDisconnected;
  final void Function(int code, String message)? onError;
}

/// Shared Web transport lifecycle for the vendor-specific chat adapters.
class WebChatRuntime<T> {
  WebChatRuntime({required this.providerId, required this.driverFactory});

  static const int _maxRememberedMessageIds = 1024;

  final String providerId;
  final WebChatDriver<T> Function() driverFactory;
  final LinkedHashSet<String> _messageIds = LinkedHashSet<String>();
  final LinkedHashSet<String> _deletedMessageIds = LinkedHashSet<String>();

  WebChatDriver<T>? _driver;
  WebChatDriverEvents? _events;
  int _generation = 0;
  bool _connecting = false;
  bool _connected = false;
  bool _disposed = false;

  Future<void> connect(
    T credentials,
    WebChatDriverEvents events, {
    WebChatTokenProvider<T>? tokenProvider,
  }) async {
    if (_disposed) {
      throw _stateError('Web chat runtime is disposed.');
    }
    if (_connecting || _connected) {
      throw _stateError('Web chat runtime is already active.');
    }

    final staleDriver = _driver;
    if (staleDriver != null) {
      _driver = null;
      _events = null;
      ++_generation;
      try {
        await staleDriver.disconnect();
      } catch (_) {
        // A provider disconnect event can arrive after its transport is gone.
      }
      try {
        await staleDriver.dispose();
      } catch (_) {
        // Continue with a new driver even if stale cleanup was incomplete.
      }
    }

    final driver = driverFactory();
    final generation = ++_generation;
    _driver = driver;
    _events = events;
    _connecting = true;
    _connected = false;
    _messageIds.clear();
    _deletedMessageIds.clear();

    try {
      await driver.connect(
        credentials,
        _guardEvents(generation, events),
        tokenProvider: tokenProvider,
      );
    } catch (error) {
      _connecting = false;
      _connected = false;
      _events = null;
      ++_generation;
      try {
        await driver.disconnect();
      } catch (_) {
        // A failed Web SDK handshake can leave only part of a session alive.
      }
      try {
        await driver.dispose();
      } catch (_) {
        // Preserve the original connection failure.
      }
      if (identical(_driver, driver)) _driver = null;
      throw mapWebChatError(providerId, 'Unable to connect to chat.', error);
    }
    _connecting = false;
  }

  Future<void> sendMessage(String message) =>
      _command('send a message', (driver) => driver.sendMessage(message));

  Future<void> deleteMessage(String messageId) =>
      _command('delete a message', (driver) => driver.deleteMessage(messageId));

  Future<void> disconnectUser(String userId) =>
      _command('disconnect a user', (driver) => driver.disconnectUser(userId));

  Future<void> _command(
    String operation,
    Future<void> Function(WebChatDriver<T>) invoke,
  ) async {
    if (_disposed) throw _stateError('Web chat runtime is disposed.');
    if (!_connected || _driver == null) {
      throw _stateError('Web chat runtime is not connected.');
    }
    try {
      await invoke(_driver!);
    } catch (error) {
      throw mapWebChatError(providerId, 'Unable to $operation.', error);
    }
  }

  Future<void> disconnect() async {
    final driver = _driver;
    if (driver == null) return;
    try {
      await driver.disconnect();
    } catch (error) {
      throw mapWebChatError(providerId, 'Unable to disconnect chat.', error);
    } finally {
      _connected = false;
      _connecting = false;
      _events = null;
      ++_generation;
      if (identical(_driver, driver)) _driver = null;
      try {
        await driver.dispose();
      } catch (_) {
        // Disconnect already ended the public session. Disposal is best effort.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await disconnect();
    } finally {
      _disposed = true;
      _events = null;
      _messageIds.clear();
      _deletedMessageIds.clear();
    }
  }

  WebChatDriverEvents _guardEvents(
    int generation,
    WebChatDriverEvents events,
  ) => WebChatDriverEvents(
    onConnecting: (reconnecting) {
      if (!_isCurrent(generation)) return;
      _connecting = true;
      _connected = false;
      events.onConnecting?.call(reconnecting);
    },
    onConnected: () {
      if (!_isCurrent(generation)) return;
      _connecting = false;
      _connected = true;
      events.onConnected?.call();
    },
    onDisconnected: (reason) {
      if (!_isCurrent(generation)) return;
      _connected = false;
      _connecting = false;
      events.onDisconnected?.call(reason);
    },
    onMessage: (message) {
      if (!_isCurrent(generation)) return;
      final id = message['id']?.toString().trim() ?? '';
      if (id.isEmpty || !_remember(_messageIds, id)) return;
      events.onMessage?.call(Map.unmodifiable(message));
    },
    onMessageDeleted: (messageId) {
      if (!_isCurrent(generation)) return;
      final id = messageId.trim();
      if (id.isEmpty || !_remember(_deletedMessageIds, id)) return;
      events.onMessageDeleted?.call(id);
    },
    onUserDisconnected: (userId) {
      if (_isCurrent(generation) && userId.trim().isNotEmpty) {
        events.onUserDisconnected?.call(userId.trim());
      }
    },
    onError: (code, message) {
      if (!_isCurrent(generation)) return;
      final error = mapWebChatError(
        providerId,
        'Web chat provider reported an error.',
        _ProviderEventError(code, message),
      );
      events.onError?.call(code, error.message);
    },
  );

  bool _isCurrent(int generation) =>
      !_disposed && generation == _generation && _events != null;

  bool _remember(LinkedHashSet<String> values, String id) {
    if (!values.add(id)) return false;
    if (values.length > _maxRememberedMessageIds) values.remove(values.first);
    return true;
  }

  ChatError _stateError(String message) => ChatError(
    code: ChatErrorCode.invalidState,
    message: message,
    providerId: providerId,
  );
}

ChatError mapWebChatError(String providerId, String fallback, Object error) {
  if (error is ChatError) return error.withProvider(providerId);
  if (error is UnsupportedError) {
    return ChatError(
      code: ChatErrorCode.unsupportedFeature,
      message: error.message ?? fallback,
      providerId: providerId,
      details: error,
    );
  }
  final rawMessage = error is _ProviderEventError
      ? error.message
      : error.toString();
  final message = rawMessage.toLowerCase();
  final code =
      error is _ProviderEventError && error.code == 403 ||
          message.contains('forbidden') ||
          message.contains('permission')
      ? ChatErrorCode.forbidden
      : error is _ProviderEventError && error.code == 401 ||
            message.contains('unauthorized') ||
            message.contains('token') ||
            message.contains('authentication')
      ? ChatErrorCode.unauthorized
      : message.contains('timeout')
      ? ChatErrorCode.timeout
      : message.contains('network') || message.contains('offline')
      ? ChatErrorCode.network
      : ChatErrorCode.nativeError;
  return ChatError(
    code: code,
    message: '$fallback $rawMessage',
    providerId: providerId,
    details: error,
  );
}

class _ProviderEventError implements Exception {
  const _ProviderEventError(this.code, this.message);

  final int code;
  final String message;
}
