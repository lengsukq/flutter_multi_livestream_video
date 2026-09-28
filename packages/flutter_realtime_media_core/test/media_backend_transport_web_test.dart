import 'package:flutter_realtime_media_core/src/client/media_backend_transport_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'web transport sends request data and decodes the response body',
    () async {
      final transport = WebMediaBackendTransport(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url, Uri.https('api.example.test', '/rooms'));
          expect(request.headers['authorization'], 'Bearer token');
          expect(request.body, '{"roomCode":"room-1"}');
          return http.Response('{"ok":true}', 201);
        }),
      );

      final response = await transport.send(
        method: 'POST',
        uri: Uri.https('api.example.test', '/rooms'),
        headers: const {
          'authorization': 'Bearer token',
          'content-type': 'application/json',
        },
        body: '{"roomCode":"room-1"}',
      );

      expect(response.statusCode, 201);
      expect(response.body, '{"ok":true}');
      transport.close();
    },
  );
}
