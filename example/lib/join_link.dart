import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Room-code based client for demo-server. Keys never touch the app.
///
/// Room codes are short (e.g. "482913"), mapped server-side to Chime meetings.
/// Legacy invite links / raw meetingIds are still accepted and resolved by
/// the server, but the UI only speaks room codes.
class RoomLink {
  final String server;
  final String? roomCode;
  final String nickname;

  const RoomLink({required this.server, this.roomCode, required this.nickname});

  static String defaultNickname() =>
      'user-${DateTime.now().millisecondsSinceEpoch % 100000}';

  /// Parses: bare "482913" (preferred), chimedemo://join?meetingId=xxx&server=...,
  /// http(s) join URLs, or raw Chime meetingIds. Returns null when unusable.
  static RoomLink? parse(String text, {required String fallbackServer}) {
    final input = text.trim();
    if (input.isEmpty) return null;
    var server = fallbackServer.trim();
    String? code;
    String? nickname;

    final uri = Uri.tryParse(input);
    if (uri != null && uri.hasScheme) {
      if (uri.queryParameters['server']?.isNotEmpty == true) {
        server = uri.queryParameters['server']!.trim();
      }
      if (uri.queryParameters['meetingId']?.isNotEmpty == true) {
        code = uri.queryParameters['meetingId']!.trim();
      }
      if (uri.queryParameters['roomCode']?.isNotEmpty == true) {
        code = uri.queryParameters['roomCode']!.trim();
      }
      if (uri.queryParameters['nickname']?.isNotEmpty == true) {
        nickname = uri.queryParameters['nickname']!.trim();
      }
      if (code == null &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[uri.pathSegments.length - 2] == 'j') {
        code = uri.pathSegments.last.trim();
      }
      if (code == null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        server =
            '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
      }
    } else {
      code = input;
    }

    if (server.isEmpty) return null;
    if (server.endsWith('/')) server = server.substring(0, server.length - 1);
    if (code != null && code.isEmpty) code = null;
    return RoomLink(
      server: server,
      roomCode: code,
      nickname: (nickname == null || nickname.isEmpty)
          ? defaultNickname()
          : nickname,
    );
  }
}

/// Result of create/join: room code + credentials for ChimeMeetingView.
class RoomSession {
  final String roomCode;
  final Map<String, dynamic> meeting;
  final Map<String, dynamic>? attendee;

  const RoomSession({
    required this.roomCode,
    required this.meeting,
    this.attendee,
  });
}

/// Thin client for demo-server room API.
class DemoBackend {
  final String server;
  final http.Client _http;

  DemoBackend(this.server, [http.Client? httpClient])
    : _http = httpClient ?? http.Client();

  void dispose() => _http.close();

  Future<RoomSession> createRoom({
    String? roomCode,
    required String nickname,
  }) async {
    final uri = Uri.parse('$server/rooms');
    final body = <String, String>{'nickname': nickname};
    if (roomCode != null && roomCode.isNotEmpty) body['roomCode'] = roomCode;
    debugPrint(
      'POST $uri create room ${body['roomCode'] ?? '(auto)'} as $nickname',
    );
    final resp = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 409) {
      throw '房间号已被占用 — 换一个号，或直接加入它。';
    }
    if (resp.statusCode == 400) {
      throw '房间号不合法 — 用4-12位字母/数字。';
    }
    if (resp.statusCode != 200) {
      throw '创建失败 (${resp.statusCode})。demo-server 在 $server 跑着吗？';
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return RoomSession(
      roomCode: data['roomCode'] as String,
      meeting: data['meeting'] as Map<String, dynamic>,
      attendee: data['attendee'] as Map<String, dynamic>?,
    );
  }

  Future<RoomSession> joinRoom({
    required String roomCode,
    required String nickname,
  }) async {
    final code = roomCode.trim();
    if (code.isEmpty) throw '先填房间号。';
    final uri = Uri.parse('$server/rooms/$code/join');
    debugPrint('POST $uri as $nickname');
    final resp = await _http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': nickname}),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 404) {
      throw '房间 $code 不存在 — 问房主要个新房号。';
    }
    if (resp.statusCode != 200) {
      throw '加入失败 (${resp.statusCode})。demo-server 在 $server 跑着吗？';
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['meeting'] == null || data['attendee'] == null) {
      throw '服务器回包缺字段 — missing meeting/attendee。';
    }
    return RoomSession(
      roomCode: data['roomCode'] as String? ?? code,
      meeting: data['meeting'] as Map<String, dynamic>,
      attendee: data['attendee'] as Map<String, dynamic>,
    );
  }

  /// Best-effort presence: heartbeat keeps the room alive, leave logs it.
  /// Never throws — room auto-close covers failures.
  Future<void> heartbeat(String roomCode) async {
    try {
      await _http
          .post(
            Uri.parse('$server/rooms/${roomCode.trim()}/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> leave(String roomCode, {String? attendeeId}) async {
    try {
      await _http
          .post(
            Uri.parse('$server/rooms/${roomCode.trim()}/leave'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'attendeeId': attendeeId}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
