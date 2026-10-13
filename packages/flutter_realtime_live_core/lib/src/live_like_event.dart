import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

class LiveLikeEvent {
  const LiveLikeEvent({
    required this.id,
    required this.sequence,
    required this.userId,
    required this.quantity,
    required this.timestamp,
  });
  final String id, userId;
  final int sequence, quantity;
  final DateTime timestamp;

  factory LiveLikeEvent.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(
        () => LiveLikeEvent(
          id: JsonReader(value).required<String>('id'),
          sequence: JsonReader(value).required<int>('sequence'),
          userId: JsonReader(value).required<String>('userId'),
          quantity: JsonReader(value).required<int>('quantity'),
          timestamp: JsonReader(value).dateTime('timestamp'),
        ),
      );
}
