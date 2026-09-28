import 'dart:async';

typedef ChatBackendTokenProvider = FutureOr<String?> Function();
typedef ChatBackendHeadersProvider =
    FutureOr<Map<String, String>> Function();

class ChatBackendConfig {
  const ChatBackendConfig({
    required this.backendUrl,
    this.tokenProvider,
    this.headersProvider,
    this.requestTimeout = const Duration(seconds: 15),
  });

  factory ChatBackendConfig.fromUrl(
    String backendUrl, {
    ChatBackendTokenProvider? tokenProvider,
    ChatBackendHeadersProvider? headersProvider,
    Duration requestTimeout = const Duration(seconds: 15),
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
    return ChatBackendConfig(
      backendUrl: uri,
      tokenProvider: tokenProvider,
      headersProvider: headersProvider,
      requestTimeout: requestTimeout,
    );
  }

  final Uri backendUrl;
  final ChatBackendTokenProvider? tokenProvider;
  final ChatBackendHeadersProvider? headersProvider;
  final Duration requestTimeout;
}
