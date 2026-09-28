import 'package:flutter/material.dart';

class MediaProviderPresentation {
  const MediaProviderPresentation({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;
}

const Map<String, MediaProviderPresentation> _mediaProviderPresentations = {
  'aws': MediaProviderPresentation(
    label: 'AWS',
    background: Color(0xFFFFF7ED),
    border: Color(0xFFFED7AA),
    foreground: Color(0xFFEA580C),
  ),
  'ivs': MediaProviderPresentation(
    label: 'AWS · IVS',
    background: Color(0xFFFFF7ED),
    border: Color(0xFFFED7AA),
    foreground: Color(0xFFEA580C),
  ),
  'artc': MediaProviderPresentation(
    label: 'Alibaba Cloud ARTC',
    background: Color(0xFFF0FDF4),
    border: Color(0xFFBBF7D0),
    foreground: Color(0xFF16A34A),
  ),
  'agora': MediaProviderPresentation(
    label: 'Agora',
    background: Color(0xFFF5F3FF),
    border: Color(0xFFDDD6FE),
    foreground: Color(0xFF7C3AED),
  ),
  'livekit': MediaProviderPresentation(
    label: 'LiveKit',
    background: Color(0xFFF0F9FF),
    border: Color(0xFFBAE6FD),
    foreground: Color(0xFF0284C7),
  ),
  'trtc': MediaProviderPresentation(
    label: 'Tencent TRTC',
    background: Color(0xFFFFF1F0),
    border: Color(0xFFFECACA),
    foreground: Color(0xFFD94645),
  ),
  'chime': MediaProviderPresentation(
    label: 'AWS · Chime',
    background: Color(0xFFFFF7ED),
    border: Color(0xFFFED7AA),
    foreground: Color(0xFFEA580C),
  ),
};

MediaProviderPresentation mediaProviderPresentation(String providerId) {
  final normalized = providerId.trim().toLowerCase();
  final known = _mediaProviderPresentations[normalized];
  if (known != null) return known;
  return MediaProviderPresentation(
    label: providerId.trim().isEmpty ? providerId : providerId.toUpperCase(),
    background: const Color(0xFFEEF2FF),
    border: const Color(0xFFC7D2FE),
    foreground: const Color(0xFF4F46E5),
  );
}

/// Returns a user-facing provider name without leaking presentation switches
/// throughout application and room UI code.
String mediaProviderDisplayName(String providerId) =>
    mediaProviderPresentation(providerId).label;
