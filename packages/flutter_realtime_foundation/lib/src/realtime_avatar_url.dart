/// HTTP(S) image references used for presentation, never identity or authority.
abstract final class RealtimeAvatarUrl {
  static String? tryParse(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty || text.length > 2048) return null;
    final uri = Uri.tryParse(text);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return text;
  }
}
