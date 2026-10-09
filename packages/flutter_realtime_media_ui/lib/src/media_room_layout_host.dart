import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_realtime_chat_core/flutter_realtime_chat_core.dart';
import 'package:flutter_realtime_media_core/flutter_realtime_media_core.dart';

import 'media_room_view.dart';

/// Explicit operations and presentation state consumed by room layouts.
///
/// Meeting and Live widgets must not know a parent State's private fields or
/// mutate room state directly. This contract also makes each layout
/// independently replaceable and testable.
abstract interface class MediaRoomLayoutHost {
  MediaRoomView get view;
  MediaSession get session;
  MediaBackgroundEffectsController get backgroundEffects;
  bool get chatOpen;
  bool get participantsOpen;
  bool get rtcDataOpen;
  bool get copied;
  bool get cleanScreen;
  int get unreadChatCount;
  int get likeCount;
  Object? get error;
  MediaRoomLayoutMode get layoutMode;
  ValueNotifier<int> get chatRevision;
  ValueListenable<List<ChatMessage>> get chatMessages;
  ValueNotifier<int> get likeRevision;
  ValueNotifier<int> get controlRevision;
  bool get liveChatInputOpen;

  Widget connectionBanner(MediaSessionState state);
  Widget errorView();
  Widget rtcData();
  Widget mediaStage(MediaSnapshot snapshot);
  Widget sidePanel(MediaSnapshot snapshot);
  Widget providerBadge(String id);
  Widget floatingHeartsOverlay();
  void copyCode();
  void setLayoutMode(MediaRoomLayoutMode mode);
  void openParticipants();
  void toggleChat();
  void toggleCleanScreen();
  void sendLike();
  void showLiveChatInputSheet();
  void hideLiveChatInput();
  Future<void> sendLiveChat();
  void showLiveGiftSheet();
  void showMeetingMoreSheet(
    MediaSnapshot snapshot,
    InteractiveMediaSession? interactive,
  );
  Future<void> showMeetingLeaveConfirmation();
  Future<void> showLiveHostLeaveConfirmation();
  Future<void> leave();
  Future<void> openBackgroundEffects();
  Future<void> runAction(Future<void> Function() action);
}
