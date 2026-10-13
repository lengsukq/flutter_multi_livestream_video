import 'dart:convert';
import 'package:flutter_realtime_live_preset/flutter_realtime_live_preset.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'HTTP repository uses participant credentials and preserves base URL path',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'roomCode': 'live1',
            'revision': 1,
            'selfUserId': 'alice',
            'recipientId': 'host',
            'canSendGift': true,
            'catalog': <Object?>[],
            'events': <Object?>[],
            'totals': <String, int>{},
          }),
          200,
        );
      });
      final repository = HttpLiveInteractionRepository(
        backendUrl: 'https://example.test/api',
        roomCode: 'live1',
        participantId: 'p1',
        participantCredential: 'proof',
        tokenProvider: () => 'bearer',
        client: client,
      );
      await repository.snapshot();
      await repository.sendGift('star', 1, eventId: 'retry-gift-001');
      await repository.sendLike(eventId: 'retry-like-001');
      expect(requests[0].url.path, '/api/rooms/live1/live/snapshot');
      expect(requests[0].headers['Authorization'], 'Bearer bearer');
      expect(
        jsonDecode(requests[1].body),
        containsPair('participantCredential', 'proof'),
      );
      expect(
        jsonDecode(requests[1].body),
        containsPair('eventId', 'retry-gift-001'),
      );
      expect(requests[2].url.path, '/api/rooms/live1/live/like');
      expect(
        jsonDecode(requests[2].body),
        containsPair('eventId', 'retry-like-001'),
      );
      repository.close();
      client.close();
    },
  );
}
