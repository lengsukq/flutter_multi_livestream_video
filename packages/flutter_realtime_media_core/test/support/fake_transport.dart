import 'dart:async';
import 'dart:convert';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// One captured HTTP request.
class CapturedRequest {
  const CapturedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;

  /// Decoded request body, or null when there is none.
  Map<String, dynamic>? get json {
    final raw = body;
    if (raw == null || raw.trim().isEmpty) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  }
}

/// Injectable transport that records requests and returns canned responses.
class FakeTransport implements MediaBackendTransport {
  FakeTransport(this.handler);

  /// Handler receiving each request; return a response or throw.
  final FutureOr<MediaBackendTransportResponse> Function(CapturedRequest)
  handler;

  final List<CapturedRequest> requests = [];
  bool closed = false;

  /// Requests that targeted [path] (path only, no query).
  Iterable<CapturedRequest> requestsTo(String path) =>
      requests.where((request) => request.uri.path == path);

  @override
  Future<MediaBackendTransportResponse> send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    final request = CapturedRequest(
      method: method,
      uri: uri,
      headers: Map.unmodifiable(headers),
      body: body,
    );
    requests.add(request);
    return handler(request);
  }

  @override
  void close() => closed = true;
}

/// Builds a JSON response.
MediaBackendTransportResponse jsonResponse(
  Object? body, {
  int statusCode = 200,
}) => MediaBackendTransportResponse(
  statusCode: statusCode,
  body: body == null ? '' : jsonEncode(body),
);

/// A provider-shaped join response for the generic contract.
Map<String, Object?> liveKitJoinPayload({
  String provider = 'livekit',
  String roomCode = '482913',
  String participantId = 'host-a',
  String role = 'host',
  String url = 'ws://192.168.31.8:7880',
  String token = 'jwt-token',
}) => {
  'contractVersion': 1,
  'provider': provider,
  'role': role,
  'roomCode': roomCode,
  'participantId': participantId,
  'livekit': {'url': url, 'token': token, 'identity': participantId},
};

/// A legacy Chime-shaped response with no provider field.
Map<String, Object?> chimeJoinPayload({String roomCode = '482913'}) => {
  'contractVersion': 1,
  'roomCode': roomCode,
  'meeting': {
    'MeetingId': 'meeting-1',
    'ExternalMeetingId': 'external-1',
    'MediaRegion': 'ap-southeast-1',
    'MediaPlacement': {
      'AudioHostUrl': 'https://audio.example.com',
      'AudioFallbackUrl': 'https://fallback.example.com',
      'SignalingUrl': 'wss://signal.example.com',
      'TurnControlUrl': 'https://turn.example.com',
    },
  },
  'attendee': {
    'AttendeeId': 'attendee-1',
    'ExternalUserId': 'leo',
    'JoinToken': 'short-lived-token',
  },
};
