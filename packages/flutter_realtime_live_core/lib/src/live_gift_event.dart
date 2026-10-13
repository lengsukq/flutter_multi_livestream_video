import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

class LiveGiftEvent {
  const LiveGiftEvent({
    required this.id,
    required this.sequence,
    required this.userId,
    required this.displayName,
    required this.recipientId,
    required this.giftId,
    required this.quantity,
    required this.timestamp,
  });
  final String id, userId, displayName, recipientId, giftId;
  final int sequence, quantity;
  final DateTime timestamp;
  factory LiveGiftEvent.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => LiveGiftEvent._fromJsonUnchecked(value));
  factory LiveGiftEvent._fromJsonUnchecked(Map<String, dynamic> value) =>
      LiveGiftEvent(
        id: JsonReader(value).required<String>('id'),
        sequence: JsonReader(value).required<int>('sequence'),
        userId: JsonReader(value).required<String>('userId'),
        displayName: JsonReader(value).required<String>('displayName'),
        recipientId: JsonReader(value).required<String>('recipientId'),
        giftId: JsonReader(value).required<String>('giftId'),
        quantity: JsonReader(value).required<int>('quantity'),
        timestamp: JsonReader(value).dateTime('timestamp'),
      );
}

/// A confirmed room-wide like, keyed by the shared interaction revision.
