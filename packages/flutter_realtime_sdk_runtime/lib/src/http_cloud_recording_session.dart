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
    this.transport,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _baseUrl = Uri.parse(backendUrl);

  final Uri _baseUrl;
  final String roomCode;
  final String participantId;
  final String? participantCredential;
  final String? roomOwnerCredential;
  final Future<String?> Function()? tokenProvider;
  final MediaBackendTransport? transport;
  final Duration requestTimeout;
  final RealtimeHttpExecutor _executor = RealtimeHttpExecutor();

  Future<Map<String, dynamic>> _request(
    String action, [
    Map<String, dynamic> options = const {},
  ]) async {
    final uri = _baseUrl.resolve(
      '/rooms/${Uri.encodeComponent(roomCode)}/recording/$action',
    );
    final transport = this.transport;
    return _executor.request(
      method: 'POST',
      uri: uri,
      timeout: requestTimeout,
      domain: 'recording',
      headers: () async {
        final token = await tokenProvider?.call();
        return {
          'Content-Type': 'application/json',
          'X-Media-Backend-Contract': '1',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        };
      },
      body: {
        'requesterParticipantId': participantId,
        if (participantCredential != null)
          'participantCredential': participantCredential,
        if (roomOwnerCredential != null)
          'roomOwnerCredential': roomOwnerCredential,
        ...options,
      },
      transport: transport == null
          ? null
          : (headers, body, abort) async {
              final response = await transport.send(
                method: 'POST',
                uri: uri,
                headers: headers,
                body: body,
              );
              return (response.statusCode, response.body);
            },
    );
  }

  RecordingResult _result(Map<String, dynamic> data) {
    final reader = JsonReader(data);
    final stateName = reader.required<String>('state');
    final taskState = RecordingTaskState.values
        .where((state) => state.name == stateName)
        .firstOrNull;
    if (taskState == null) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'recording.state',
      );
    }
    final id = reader.optional<String>('recordingId');
    return RecordingResult(
      mode: RecordingMode.cloud,
      taskState: taskState,
      recordingId: id,
      fileName: reader.optional<String>('fileName'),
      mimeType: 'video/mp4',
      fileSizeBytes: reader.optional<num>('fileSizeBytes')?.toInt() ?? 0,
      metadata: {
        if (data['provider'] != null)
          'provider': reader.required<String>('provider'),
        'canDownload': data['canDownload'] == true,
        if (data['recordingAvailable'] is bool)
          'recordingAvailable': data['recordingAvailable'],
        if (data['recordingUnavailableReason'] is String)
          'recordingUnavailableReason': data['recordingUnavailableReason'],
        // Backend recorder failures are part of the public recording result:
        // the Demo needs the reason even when the remote task has failed.
        if (data['error'] is String) 'error': data['error'],
        if (data['layout'] != null) 'layout': data['layout'],
        if (data['supportedLayouts'] is List)
          'supportedLayouts': List<String>.from(
            (data['supportedLayouts'] as List).whereType<String>(),
          ),
        if (data['preset'] != null) 'preset': data['preset'],
      },
    );
  }

  @override
  Future<RecordingResult> startCloudRecording(RecordingOptions options) async {
    if (options.mode != RecordingMode.cloud) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidArgument,
        message: 'recording.start.options',
      );
    }
    if (options.containerFormat != RecordingContainerFormat.mp4 ||
        options.streamType != RecordingStreamType.both) {
      throw const RealtimeException(
        code: RealtimeErrorCode.unsupportedFeature,
        message: 'recording.start.format',
      );
    }
    final response = await _request('start', {
      'layout': options.layout.name,
      'streamType': options.streamType.name,
      'containerFormat': options.containerFormat.name,
      'rawProviderParams': {
        ...options.rawProviderParams,
        'preset': options.qualityPreset == RecordingQualityPreset.fullHd1080p30
            ? 'H264_1080P_30'
            : 'H264_720P_30',
      },
    });
    final result = _result(response);
    if (result.recordingId == null || result.recordingId!.isEmpty) {
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'recording.start.id',
      );
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
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'recording.download.url',
      );
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
      throw const RealtimeException(
        code: RealtimeErrorCode.invalidResponse,
        message: 'recording.download.origin',
      );
    }
    return url;
  }

  @override
  void dispose() {
    _executor.close();
  }
}
