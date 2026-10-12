import 'dart:convert';

import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

/// Backend-neutral HTTP implementation of the cloud recording contract.
/// Providers, their API secrets, and storage remain server-side.
class HttpCloudRecordingSession implements MediaCloudRecordingSession {
  HttpCloudRecordingSession({
    required String backendUrl,
    required this.roomCode,
    required this.participantId,
    required this.participantCredential,
    this.roomOwnerCredential,
    this.tokenProvider,
    MediaBackendTransport? transport,
  }) : _baseUrl = Uri.parse(backendUrl),
       _transport = transport ?? createDefaultMediaBackendTransport(),
       _ownsTransport = transport == null;

  final Uri _baseUrl;
  final String roomCode;
  final String participantId;
  final String? participantCredential;
  final String? roomOwnerCredential;
  final Future<String?> Function()? tokenProvider;
  final MediaBackendTransport _transport;
  final bool _ownsTransport;

  Future<Map<String, dynamic>> _request(
    String action, [
    Map<String, dynamic> options = const {},
  ]) async {
    final token = await tokenProvider?.call();
    final response = await _transport.send(
      method: 'POST',
      uri: _baseUrl.resolve(
        '/rooms/${Uri.encodeComponent(roomCode)}/recording/$action',
      ),
      headers: {
        'Content-Type': 'application/json',
        'X-Media-Backend-Contract': '1',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'requesterParticipantId': participantId,
        if (participantCredential != null)
          'participantCredential': participantCredential,
        if (roomOwnerCredential != null)
          'roomOwnerCredential': roomOwnerCredential,
        ...options,
      }),
    );
    Map<String, dynamic> json;
    try {
      json = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'Cloud recording backend returned invalid JSON.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final details = json['error'];
      final text = details is Map ? details['message'] : details;
      throw RealtimeException(
        code: response.statusCode == 403
            ? RealtimeErrorCode.permissionDenied
            : response.statusCode == 400
            ? RealtimeErrorCode.unsupportedFeature
            : RealtimeErrorCode.invalidState,
        message: 'Cloud recording: ${text ?? 'HTTP ${response.statusCode}'}',
      );
    }
    return json;
  }

  RecordingResult _result(Map<String, dynamic> data) {
    final id = data['recordingId'] as String?;
    return RecordingResult(
      mode: RecordingMode.cloud,
      recordingId: id,
      fileName: data['fileName'] as String?,
      mimeType: 'video/mp4',
      fileSizeBytes: (data['fileSizeBytes'] as num?)?.toInt() ?? 0,
      metadata: {
        'provider': data['provider'] ?? 'livekit',
        'state': data['state'] ?? 'idle',
        'canDownload': data['canDownload'] == true,
        if (data['recordingAvailable'] is bool)
          'recordingAvailable': data['recordingAvailable'],
        if (data['recordingUnavailableReason'] is String)
          'recordingUnavailableReason': data['recordingUnavailableReason'],
        if (data['error'] != null) 'error': data['error'],
        if (data['layout'] != null) 'layout': data['layout'],
      },
    );
  }

  @override
  Future<RecordingResult> startCloudRecording(RecordingOptions options) async {
    if (options.mode != RecordingMode.cloud) {
      throw ArgumentError('Expected cloud recording options.');
    }
    if (options.containerFormat != RecordingContainerFormat.mp4 ||
        options.streamType != RecordingStreamType.both) {
      throw UnsupportedError('Cloud V1 supports composite MP4 audio/video.');
    }
    final response = await _request('start', {
      'layout': options.layout.name,
      'streamType': options.streamType.name,
      'containerFormat': options.containerFormat.name,
      if (options.rawProviderParams.isNotEmpty)
        'rawProviderParams': options.rawProviderParams,
    });
    final result = _result(response);
    if (result.recordingId == null || result.recordingId!.isEmpty) {
      throw StateError('Cloud recorder did not return a real recording id.');
    }
    return result;
  }

  @override
  Future<RecordingResult> stopCloudRecording() async =>
      _result(await _request('stop'));

  @override
  Future<RecordingResult> queryCloudRecording() async =>
      _result(await _request('status'));

  @override
  Future<Uri> cloudRecordingDownloadUrl() async {
    final reply = await _request('download');
    final raw = reply['downloadUrl'];
    if (raw is! String) {
      throw StateError('Cloud recording is not ready to download.');
    }
    final parsed = Uri.tryParse(raw);
    final url = parsed == null ? null : _baseUrl.resolveUri(parsed);
    // The host app already selected this backend URL. Never allow a
    // downloaded link to redirect to another origin; local development may
    // use plain HTTP (e.g. a phone accessing a LAN demo server).
    if (url == null ||
        url.host != _baseUrl.host ||
        url.port != _baseUrl.port ||
        url.scheme != _baseUrl.scheme ||
        (url.scheme != 'http' && url.scheme != 'https')) {
      throw StateError('Cloud backend returned an invalid download URL.');
    }
    return url;
  }

  @override
  void dispose() {
    if (_ownsTransport) _transport.close();
  }
}
