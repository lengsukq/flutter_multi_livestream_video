import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';

/// Presentation-only roles, deliberately separate from provider credentials.
///
/// Meeting owners are identified by *room management authority*, not by the
/// symmetric RTC participant role. A non-viewer is not necessarily a Live host.
enum RealtimePresentationRole {
  meetingHost,
  meetingParticipant,
  liveHost,
  liveViewer,
  liveParticipant,
  chatHost,
  chatMember,
  chatViewer;

  bool get canShowLiveHostTools => this == RealtimePresentationRole.liveHost;

  bool get canShowChatHostTools => this == RealtimePresentationRole.chatHost;

  String label({required bool isZh}) => switch (this) {
    RealtimePresentationRole.meetingHost => isZh ? '会议主持人' : 'Meeting host',
    RealtimePresentationRole.meetingParticipant =>
      isZh ? '会议参会者' : 'Meeting participant',
    RealtimePresentationRole.liveHost => isZh ? '主播' : 'Broadcaster',
    RealtimePresentationRole.liveViewer => isZh ? '观众' : 'Viewer',
    RealtimePresentationRole.liveParticipant =>
      isZh ? '直播参与者' : 'Live participant',
    RealtimePresentationRole.chatHost => isZh ? '聊天室房主' : 'Chat host',
    RealtimePresentationRole.chatMember => isZh ? '聊天室成员' : 'Chat member',
    RealtimePresentationRole.chatViewer => isZh ? '聊天室观众' : 'Chat viewer',
  };

  static RealtimePresentationRole forMeetingOwner(bool isLogicalOwner) =>
      isLogicalOwner
      ? RealtimePresentationRole.meetingHost
      : RealtimePresentationRole.meetingParticipant;

  static RealtimePresentationRole forMeeting(MediaRoomSession media) =>
      forMeetingOwner(media.isLogicalOwner);

  static RealtimePresentationRole forLive(MediaRole role) => switch (role) {
    MediaRole.host => RealtimePresentationRole.liveHost,
    MediaRole.viewer => RealtimePresentationRole.liveViewer,
    // A Meeting participant may be routed to a Live layout incorrectly.
    // Never grant host controls simply because they are not a viewer.
    MediaRole.participant => RealtimePresentationRole.liveParticipant,
  };

  static RealtimePresentationRole forChat(ChatRole role) => switch (role) {
    ChatRole.host => RealtimePresentationRole.chatHost,
    ChatRole.viewer => RealtimePresentationRole.chatViewer,
    ChatRole.participant => RealtimePresentationRole.chatMember,
  };
}
