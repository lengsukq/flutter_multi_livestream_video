import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

class WhiteboardPage {
  const WhiteboardPage({required this.id, required this.title});
  final String id, title;
  factory WhiteboardPage.fromJson(Map<String, dynamic> value) =>
      JsonReader(value).decode(() => WhiteboardPage._fromJsonUnchecked(value));
  factory WhiteboardPage._fromJsonUnchecked(Map<String, dynamic> value) =>
      WhiteboardPage(
        id: JsonReader(value).required<String>('id'),
        title: JsonReader(value).required<String>('title'),
      );
}
