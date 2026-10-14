import 'package:flutter_realtime_classroom_core/flutter_realtime_classroom_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'classroom snapshots retain member avatars across media telemetry updates',
    () {
      const image = 'https://avatar.test/member.png';
      final member = ClassroomStudent.fromJson({
        'userId': 'u',
        'participantId': 'p',
        'displayName': '小明',
        'avatarUrl': image,
      });
      expect(member.withMedia(microphoneOn: true).avatarUrl, image);
      final question = ClassroomQuestion.fromJson({
        'id': 'q',
        'userId': 'u',
        'displayName': '小明',
        'avatarUrl': image,
        'text': 'question',
        'status': 'pending',
        'createdAt': '2026-10-14T00:00:00Z',
      });
      expect(question.avatarUrl, image);
      expect(
        ClassroomFeedback.fromJson({
          'id': 'f',
          'userId': 'u',
          'avatarUrl': image,
          'kind': 'understood',
          'createdAt': '2026-10-14T00:00:00Z',
        }).avatarUrl,
        image,
      );
      expect(
        ClassroomAttendance.fromJson({
          'userId': 'u',
          'displayName': '小明',
          'online': true,
          'avatarUrl': image,
        }).avatarUrl,
        image,
      );
      expect(
        ClassroomStudent.fromJson({
          'userId': 'u',
          'participantId': 'p',
        }).avatarUrl,
        isNull,
      );
    },
  );
}
