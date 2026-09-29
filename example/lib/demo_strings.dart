import 'package:flutter/material.dart';

/// Localized strings used by the example app's own screens.
///
/// Reusable SDK widgets have their own localization surface; this class keeps
/// example-only copy out of the SDK package.
class DemoStrings {
  const DemoStrings._(this.isZh);

  final bool isZh;

  static DemoStrings of(BuildContext context) => DemoStrings._(
    Localizations.localeOf(context).languageCode.toLowerCase() == 'zh',
  );

  String get appSubtitle =>
      isZh ? '多服务商直播与音视频 SDK' : 'Multi-Provider Livestream & Video SDK';
  String get backendServiceEndpoint =>
      isZh ? '后端服务地址' : 'Backend Service Endpoint';
  String get demoBackendUrl => isZh ? 'Demo 后端 URL' : 'Demo Backend URL';
  String get demoIdentity => isZh ? 'Demo 身份' : 'Demo identity';
  String get demoIdentityDescription => isZh
      ? '视频、会议、直播和 Chat 统一使用同一个 User ID 与显示名称。'
      : 'Video, meetings, live sessions, and Chat share the same User ID and display name.';
  String get userId => 'User ID';
  String get displayName => isZh ? '显示名称' : 'Display name';
  String get checking => isZh ? '检查中…' : 'Checking…';
  String get check => isZh ? '检查' : 'Check';
  String get defaultServer => isZh ? '默认' : 'Default';
  String get joinRoomTab => isZh ? '加入房间' : 'Join room';
  String get createRoomTab => isZh ? '创建房间' : 'Create room';
  String get videoTab => isZh ? '视频' : 'Video';
  String get chatTab => isZh ? '聊天' : 'Chat';
  String get roomCode => isZh ? '房间码' : 'Room code';
  String get optionalRoomCode => isZh ? '房间码（可选）' : 'Room code (optional)';
  String get roomCodeHelp => isZh ? '4–12 位字母或数字' : '4–12 letters or digits';
  String get joinRoom => isZh ? '加入房间' : 'Join room';
  String get createAndJoin => isZh ? '创建并加入' : 'Create and join';
  String get random => isZh ? '随机生成' : 'Random';
  String get optionalDisplayName =>
      isZh ? '显示名称（可选）' : 'Display name (optional)';
  String get displayNameExample => isZh ? '例如：小明' : 'e.g. Alice / Bob';
  String get roomType => isZh ? '房间类型' : 'Room type';
  String get meeting => isZh ? '会议' : 'Meeting';
  String get live => isZh ? '直播' : 'Live';
  String get meetingDescription => isZh
      ? '所有人以参与者身份加入，并可控制发布音视频。'
      : 'Everyone joins as a participant with publish controls.';
  String get liveDescription => isZh
      ? '创建者为主播，其他设备以观众身份加入。'
      : 'The creator is the host; other devices join as viewers.';
  String get availableRooms => isZh ? '可加入的房间' : 'Available rooms';
  String get refresh => isZh ? '刷新' : 'Refresh';
  String get noActiveRooms => isZh ? '当前没有正在进行的房间。' : 'No active rooms found.';
  String get join => isZh ? '加入' : 'Join';
  String get enterBackendUrl =>
      isZh ? '请先输入后端 URL。' : 'Enter your backend URL first.';
  String get enterRoomCode => isZh ? '请先输入房间码。' : 'Enter a room code first.';
  String get invalidRoomCode => isZh
      ? '房间码必须为 4–12 位字母或数字。'
      : 'Room code must be 4–12 letters or digits.';

  String backendStatus(String? value, {required bool checkingNow}) {
    if (checkingNow) return checking;
    if (!isZh || value == null) return value ?? check;
    return switch (value) {
      'No URL specified' => '未填写 URL',
      'Reachable (health unavailable)' => '可以访问（健康检查不可用）',
      'Ready' => '就绪',
      'Health check failed' => '健康检查失败',
      'Unreachable' => '无法连接',
      _ when value.startsWith('Default: ') => '默认：${value.substring(9)}',
      _ => value,
    };
  }

  String roomSummary(String mode, String provider, int attendees) => isZh
      ? '$mode · $provider · $attendees 人在线'
      : '$mode · $provider · $attendees online';
}
