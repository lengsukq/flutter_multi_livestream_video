import 'recording_options.dart';

/// Structured descriptor of a provider's cloud recording REST/server API.
///
/// Designed for SDK consumers so their backend servers or custom gateway
/// can freely inspect, authenticate, and dispatch cloud recording requests
/// to the respective provider's cloud service.
class CloudRecordingDescriptor {
  const CloudRecordingDescriptor({
    required this.providerId,
    required this.action,
    required this.endpoint,
    required this.httpMethod,
    required this.suggestedHeaders,
    required this.payload,
    required this.documentationUrl,
    this.description = '',
  });

  /// The provider identifier (e.g. 'agora', 'chime', 'trtc', 'artc', 'livekit').
  final String providerId;

  /// The operation action (e.g. 'start', 'stop', 'acquire', 'query', 'updateLayout').
  final String action;

  /// The official cloud service API URL or endpoint template.
  final String endpoint;

  /// The HTTP method required by the provider (e.g. 'POST', 'GET').
  final String httpMethod;

  /// Recommended HTTP headers, including auth header schemes and content types.
  final Map<String, String> suggestedHeaders;

  /// Formatted JSON request payload assembled from [RecordingOptions]
  /// and any user-specified [RecordingOptions.rawProviderParams].
  final Map<String, dynamic> payload;

  /// Official developer reference URL for this provider's cloud recording API.
  final String documentationUrl;

  /// Human-readable description of this API operation.
  final String description;

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'action': action,
    'endpoint': endpoint,
    'httpMethod': httpMethod,
    'suggestedHeaders': suggestedHeaders,
    'payload': payload,
    'documentationUrl': documentationUrl,
    if (description.isNotEmpty) 'description': description,
  };

  @override
  String toString() =>
      'CloudRecordingDescriptor($providerId.$action -> $httpMethod $endpoint)';
}
