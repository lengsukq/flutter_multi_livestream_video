import 'package:flutter/material.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'realtime_strings.dart';
import 'realtime_ui_style.dart';

/// Optional RTC data debug console, intentionally independent from Product IM.
///
/// Owns its input, send-in-flight guard and cleanup; errors are projected
/// to the surrounding room rather than becoming unhandled Future failures.
class RoomRtcDataPanel extends StatefulWidget {
  const RoomRtcDataPanel({
    super.key,
    required this.session,
    required this.onError,
  });

  final MediaSession session;
  final ValueChanged<String?> onError;

  @override
  State<RoomRtcDataPanel> createState() => _RoomRtcDataPanelState();
}

class _RoomRtcDataPanelState extends State<RoomRtcDataPanel> {
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    final session = widget.session;
    setState(() => _sending = true);
    try {
      await session.sendData(
        text,
        options: const MediaSendOptions(topic: 'debug'),
      );
      if (!mounted || session != widget.session) return;
      _message.clear();
      widget.onError(null);
    } catch (error) {
      if (mounted && session == widget.session) {
        widget.onError(error.toString());
      }
    } finally {
      if (mounted && session == widget.session) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.session.capabilities.canSendData) {
      return const SizedBox.shrink();
    }
    final strings = RealtimeStrings.of(context);
    return RealtimeGlassSurface(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      radius: RealtimeUiTokens.controlRadius,
      opacity: .88,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: RealtimePill(
              label: strings.rtcData,
              foreground: RealtimeUiTokens.text,
              background: RealtimeUiTokens.primarySubtle,
              borderColor: RealtimeUiTokens.primaryBorder,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _message,
              decoration: InputDecoration(
                hintText: strings.debugDataPayload,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_rounded, color: RealtimeUiTokens.text),
          ),
        ],
      ),
    );
  }
}
