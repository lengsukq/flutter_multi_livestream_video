enum ChatRoomContext {
  attached,
  standalone;

  String get wireName => name;

  static ChatRoomContext tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return values.firstWhere(
      (item) => item.wireName == normalized,
      orElse: () => ChatRoomContext.attached,
    );
  }
}

class ChatRoomSummary {
  const ChatRoomSummary({
    required this.roomCode,
    required this.providerId,
    this.context = ChatRoomContext.standalone,
  });

  final String roomCode;
  final String providerId;
  final ChatRoomContext context;
}
