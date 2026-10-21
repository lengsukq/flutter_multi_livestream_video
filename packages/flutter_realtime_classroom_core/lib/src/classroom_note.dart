import 'package:flutter_realtime_foundation/flutter_realtime_foundation.dart';

enum ClassroomNoteKind { note, chapter }

/// Server-authored note or manually marked lesson chapter.
/// Elapsed time is measured from room creation, not the recording playback
/// clock. Hosts must map timestamps before building video seek links.
class ClassroomNote {
  const ClassroomNote({
    required this.id,
    required this.text,
    required this.kind,
    required this.authorUserId,
    required this.createdAt,
    required this.elapsedSeconds,
  });

  final String id;
  final String text;
  final ClassroomNoteKind kind;
  final String authorUserId;
  final DateTime createdAt;
  final int elapsedSeconds;

  factory ClassroomNote.fromJson(Map<String, dynamic> json) =>
      JsonReader(json).decode(() {
        final kind = JsonReader(
          json,
        ).enumValue('kind', ClassroomNoteKind.values);
        return ClassroomNote(
          id: JsonReader(json).required<String>('id'),
          text: JsonReader(json).required<String>('text'),
          kind: kind,
          authorUserId: JsonReader(json).required<String>('authorUserId'),
          createdAt: DateTime.parse(
            JsonReader(json).required<String>('createdAt'),
          ).toUtc(),
          elapsedSeconds: JsonReader(json).required<int>('elapsedSeconds'),
        );
      });
}
