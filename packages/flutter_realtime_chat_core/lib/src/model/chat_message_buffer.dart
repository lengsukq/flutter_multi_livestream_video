import 'chat_message.dart';

/// Bounded, timestamp-ordered session timeline. Equal timestamps retain arrival
/// order; replacing a message keeps its original arrival sequence.
class ChatMessageBuffer {
  ChatMessageBuffer({this.maxMessages = 500}) {
    if (maxMessages <= 0) {
      throw ArgumentError.value(maxMessages, 'maxMessages', 'must be positive');
    }
  }

  final int maxMessages;
  final Map<String, ChatMessage> _byId = {};
  final Map<String, int> _sequence = {};
  final List<ChatMessage> _ordered = [];
  int _nextSequence = 0;

  bool contains(String id) => _byId.containsKey(id);
  int get length => _ordered.length;
  int get indexedMessageCount => _byId.length;
  List<ChatMessage> get messages => List.unmodifiable(_ordered);

  /// Returns true only for an insertion retained in the timeline.
  bool upsert(ChatMessage message) {
    final previous = _byId[message.id];
    final isNew = previous == null;
    if (previous != null) _ordered.remove(previous);
    _sequence.putIfAbsent(message.id, () => _nextSequence++);
    _byId[message.id] = message;
    var low = 0;
    var high = _ordered.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_compare(_ordered[mid], message) <= 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    _ordered.insert(low, message);
    while (_ordered.length > maxMessages) {
      final removed = _ordered.removeAt(0);
      _byId.remove(removed.id);
      _sequence.remove(removed.id);
    }
    return isNew && _byId.containsKey(message.id);
  }

  int _compare(ChatMessage a, ChatMessage b) {
    final time = a.timestamp.compareTo(b.timestamp);
    return time != 0 ? time : _sequence[a.id]!.compareTo(_sequence[b.id]!);
  }

  void remove(String id) {
    final removed = _byId.remove(id);
    if (removed != null) _ordered.remove(removed);
    _sequence.remove(id);
  }

  void clear() {
    _ordered.clear();
    _byId.clear();
    _sequence.clear();
    _nextSequence = 0;
  }
}
