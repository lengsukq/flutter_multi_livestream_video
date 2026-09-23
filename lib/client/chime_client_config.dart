import 'dart:async';

typedef ChimeTokenProvider = FutureOr<String?> Function();
typedef ChimeHeadersProvider = FutureOr<Map<String, String>> Function();

/// Configuration for the optional HTTP backend convenience layer.
///
/// [backendUrl] points to an application backend that implements the Chime
/// backend contract. It is never an AWS access-key endpoint and this package
/// never accepts AWS long-lived credentials.
class ChimeClientConfig {
  const ChimeClientConfig({
    required this.backendUrl,
    this.tokenProvider,
    this.headersProvider,
    this.requestTimeout = const Duration(seconds: 15),
    this.heartbeatInterval = const Duration(seconds: 30),
  });

  factory ChimeClientConfig.fromUrl(
    String backendUrl, {
    ChimeTokenProvider? tokenProvider,
    ChimeHeadersProvider? headersProvider,
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
    return ChimeClientConfig(
      backendUrl: uri,
      tokenProvider: tokenProvider,
      headersProvider: headersProvider,
      requestTimeout: requestTimeout,
      heartbeatInterval: heartbeatInterval,
    );
  }

  final Uri backendUrl;
  final ChimeTokenProvider? tokenProvider;
  final ChimeHeadersProvider? headersProvider;
  final Duration requestTimeout;
  final Duration heartbeatInterval;
}
