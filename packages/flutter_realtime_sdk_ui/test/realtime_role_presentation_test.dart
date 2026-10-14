import 'package:flutter_realtime_sdk_ui/flutter_realtime_sdk_ui.dart';
import 'package:flutter_realtime_sdk_runtime/flutter_realtime_sdk_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('meeting presenter checks logical owner, not symmetric RTC role', () {
    expect(
      RealtimePresentationRole.forMeetingOwner(true),
      RealtimePresentationRole.meetingHost,
    );
    expect(
      RealtimePresentationRole.forMeetingOwner(false),
      RealtimePresentationRole.meetingParticipant,
    );
    expect(
      RealtimePresentationRole.meetingParticipant.label(isZh: true),
      '会议参会者',
    );
    expect(RealtimePresentationRole.meetingHost.label(isZh: true), '会议主持人');
  });

  test('non-viewer is NOT sufficient to show broadcaster tools', () {
    expect(
      RealtimePresentationRole.forLive(MediaRole.host).canShowLiveHostTools,
      isTrue,
    );
    expect(
      RealtimePresentationRole.forLive(MediaRole.viewer).canShowLiveHostTools,
      isFalse,
    );
    expect(
      RealtimePresentationRole.forLive(
        MediaRole.participant,
      ).canShowLiveHostTools,
      isFalse,
    );
    expect(
      RealtimePresentationRole.forLive(MediaRole.viewer).label(isZh: true),
      '观众',
    );
    expect(
      RealtimePresentationRole.forLive(MediaRole.participant).label(isZh: true),
      '直播参与者',
    );
  });

  test('connected chat roles are distinct from room creator UI', () {
    expect(
      RealtimePresentationRole.forChat(ChatRole.host).canShowChatHostTools,
      isTrue,
    );
    expect(
      RealtimePresentationRole.forChat(
        ChatRole.participant,
      ).canShowChatHostTools,
      isFalse,
    );
    expect(
      RealtimePresentationRole.forChat(ChatRole.viewer).canShowChatHostTools,
      isFalse,
    );
    expect(
      RealtimePresentationRole.forChat(ChatRole.host).label(isZh: true),
      '聊天室房主',
    );
    expect(
      RealtimePresentationRole.forChat(ChatRole.participant).label(isZh: true),
      '聊天室成员',
    );
  });
}
