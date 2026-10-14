import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'realtime_strings.dart';
import 'realtime_ui_style.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';

class LiveRoomDanmaku extends StatelessWidget {
  const LiveRoomDanmaku({
    super.key,
    required this.chat,
    required this.messages,
    required this.participantId,
    required this.isHost,
  });
  final ChatSession? chat;
  final ValueListenable<List<ChatMessage>> messages;
  final String participantId;
  final bool isHost;
  @override
  Widget build(BuildContext context) {
    final chat = this.chat;
    if (chat == null) return const SizedBox.shrink();

    return ValueListenableBuilder<List<ChatMessage>>(
      valueListenable: messages,
      builder: (context, messages, _) {
        if (messages.isEmpty) return const SizedBox.shrink();

        final recent = messages.length > 5
            ? messages.sublist(messages.length - 5)
            : messages;

        final identity = chat is ChatSessionIdentity
            ? chat as ChatSessionIdentity
            : null;
        final myId = identity?.localUserId;
        final strings = RealtimeStrings.of(context);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ShaderMask(
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Colors.transparent, Colors.white],
            stops: const [0.0, 0.25],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: recent.map((m) {
              final isOwn = m.userId == myId;
              final isAnchor = m.userId == participantId && isHost;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(
                    RealtimeUiTokens.controlRadius,
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : RealtimeUiTokens.border,
                    width: 0.8,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: RichText(
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      if (isAnchor)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              strings.anchorTag,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else if (isOwn)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: const EdgeInsets.only(right: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1D1F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              strings.meTag,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      TextSpan(
                        text:
                            '${m.displayName.isEmpty ? m.userId : m.displayName}: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isAnchor
                              ? const Color(0xFFD97706)
                              : isOwn
                              ? const Color(0xFF1D1D1F)
                              : (isDark
                                    ? const Color(0xFFCBD5E1)
                                    : RealtimeUiTokens.text),
                        ),
                      ),
                      TextSpan(
                        text: m.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : RealtimeUiTokens.text,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

/// Bottom interaction controls in livestream: comment pill, gift button, like button.
