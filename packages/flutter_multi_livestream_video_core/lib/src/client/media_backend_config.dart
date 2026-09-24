import 'dart:async';

typedef MediaTokenProvider = FutureOr<String?> Function();
typedef MediaHeadersProvider = FutureOr<Map<String, String>> Function();

/// Configuration for the optional HTTP backend convenience layer.
///
/// [backendUrl] points at an application backend that implements the media
/// backend contract. It is never a provider credential endpoint, and this
/// package never accepts provider API keys or secrets.
class MediaBackendConfig {
  const MediaBackendConfig({
    required this.backendUrl,
    this.tokenProvider,
    this.headersProvider,
    this.requestTimeout = const Duration(seconds: 15),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  factory MediaBackendConfig.fromUrl(
    String backendUrl, {
    MediaTokenProvider? tokenProvider,
    MediaHeadersProvider? headersProvider,
    Duration requestTimeout = const Duration(seconds: 15),
    Duration heartbeatInterval = const Duration(seconds: 30),
  }) {
    final uri = Uri.tryParse(backendUrl.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        backendUrl,
        'backendUrl',
        'Expected an absolute http(s) backend URL without query or fragment.',
      );
    }
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Request timeout must be greater than zero.',
      );
    }
    if (heartbeatInterval < Duration.zero) {
      throw ArgumentError.value(
        heartbeatInterval,
        'heartbeatInterval',
        'Heartbeat interval must not be negative.',
      );
    }
    return MediaBackendConfig(
      backendUrl: uri,
      tokenProvider: tokenProvider,
      headersProvider: headersProvider,
      requestTimeout: requestTimeout,
      heartbeatInterval: heartbeatInterval,
    );
  }

  final Uri backendUrl;
  final MediaTokenProvider? tokenProvider;
  final MediaHeadersProvider? headersProvider;
  final Duration requestTimeout;
  final Duration heartbeatInterval;
}
