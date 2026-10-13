import 'dart:typed_data';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'media_background_image_preset.dart';

class MediaRoomViewConfig {
  const MediaRoomViewConfig({
    this.showProvider = false,
    this.showChat = true,
    this.showRtcDataMessages = false,
    this.confirmBeforeLeave = true,
    this.initialMediaSettings,
    this.backgroundImageBytes,
    this.backgroundImagePresets = const [],
    this.roomMode,
  });
  final bool showProvider;
  final bool showChat;
  final bool showRtcDataMessages;
  final bool confirmBeforeLeave;
  final MediaLocalPreviewSettings? initialMediaSettings;
  final Uint8List? backgroundImageBytes;
  final List<MediaBackgroundImagePreset> backgroundImagePresets;

  /// Optional explicitly configured room mode.
  /// When not provided, the room view deduces meeting vs live from the
  /// participant role and attached interactions.
  final MediaRoomMode? roomMode;
}
