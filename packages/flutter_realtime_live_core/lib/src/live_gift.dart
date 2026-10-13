import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

class LiveGift {
  const LiveGift({required this.id, required this.name, required this.icon});
  final String id, name, icon;
  factory LiveGift.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => LiveGift._fromJsonUnchecked(value));
  factory LiveGift._fromJsonUnchecked(Map<String, dynamic> value) => LiveGift(
    id: JsonReader(value).required<String>('id'),
    name: JsonReader(value).required<String>('name'),
    icon: JsonReader(value).required<String>('icon'),
  );
}
