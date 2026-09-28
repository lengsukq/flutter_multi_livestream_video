import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'rtc_data_chat_session.dart';

/// Resolves the user-facing chat session while preserving backend authority.
///
/// A configured product Chat Provider always wins. Passing
/// [productChatConfigured] as true with a null [productChatSession] represents
/// a product-chat connection failure and intentionally returns null instead of
/// silently changing semantics by falling back to RTC data.
ChatSession? resolveChatSessionWithRtcFallback({
  required MediaRoomSession room,
  required bool productChatConfigured,
  ChatSession? productChatSession,
  String? userId,
  String? displayName,
}) {
  if (productChatConfigured) return productChatSession;
  return RtcDataChatSession.tryAttach(
    room: room,
    userId: userId,
    displayName: displayName,
  );
}
