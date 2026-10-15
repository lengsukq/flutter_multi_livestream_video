import 'dart:typed_data';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';
import 'package:flutter_realtime_media_ui/flutter_realtime_media_ui.dart';

class RealtimeRoomViewConfig {
  const RealtimeRoomViewConfig({
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

  /// Fallback mode for direct sessions without authoritative backend metadata.
  /// Connected backend mode takes precedence over this hint.
  final MediaRoomMode? roomMode;
}
