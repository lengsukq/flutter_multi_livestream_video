import 'package:flutter/material.dart';
import 'package:flutter_realtime_sdk/flutter_realtime_sdk.dart';

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

  /// Render the public SDK error contract instead of exposing internal
  /// exception class names to users. All screens share the same guidance.
  String displayRealtimeError(Object error) {
    if (error is! RealtimeException) return error.toString();
    final provider = error.providerId;
    final action = switch (error.suggestedAction) {
      'retry' => isZh ? '请重试。' : 'Please retry.',
      'refresh-provider-credentials' =>
        isZh ? '请重新获取连接凭证。' : 'Refresh the connection credentials.',
      'request-permission' =>
        isZh ? '请在系统设置中检查授权。' : 'Check permissions in system settings.',
      'configure-backend' =>
        isZh ? '请检查 Demo 服务地址。' : 'Check the demo backend URL.',
      'check-capabilities' =>
        isZh ? '请检查当前服务商的平台能力。' : 'Check provider and platform capabilities.',
      'load-web-provider-sdk' || 'retry-driver-initialization' =>
        isZh
            ? '请检查服务商 SDK 是否初始化成功。'
            : 'Check whether the provider SDK initialized.',
      _ => null,
    };
    return [
      error.message,
      if (provider != null && provider.isNotEmpty)
        isZh ? '服务商：$provider' : 'Provider: $provider',
      if (action != null) action,
    ].join('\n');
  }

  String get appSubtitle =>
      isZh ? '多服务商直播与音视频 SDK' : 'Multi-Provider Livestream & Video SDK';
  String get workspaceEyebrow => isZh ? '实时互动工作台' : 'REALTIME WORKSPACE';
  String get workspaceTitle => isZh ? '连接，从这里开始。' : 'Bring everyone together.';
  String get workspaceDescription => isZh
      ? '一个入口体验会议、直播与聊天。无论手机、平板还是桌面，都可以快速创建或加入。'
      : 'Meet, go live, and chat from one place. Create or join on any screen.';
  String get workspaceMeetings => isZh ? '多人会议' : 'Meetings';
  String get workspaceLive => isZh ? '互动直播' : 'Go live';
  String get workspaceChat => isZh ? '即时聊天' : 'Chat';
  String get startHere => isZh ? '选择你想做的事' : 'What would you like to do?';
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
  String get createMeeting => isZh ? '创建会议' : 'Create meeting';
  String get startLive => isZh ? '开始直播' : 'Start live';
  String get videoTab => isZh ? '视频' : 'Video';
  String get meetingTab => isZh ? '会议' : 'Meeting';
  String get livestreamTab => isZh ? '直播' : 'Livestream';
  String get chatTab => isZh ? '聊天' : 'Chat';
  String get watchLiveStream => isZh ? '观看直播' : 'Watch Live';
  String get hostBroadcast => isZh ? '我要开播' : 'Go Live';
  String get liveStreamList => isZh ? '活跃直播间' : 'Live Streams';
  String get meetingList => isZh ? '进行中会议' : 'Meetings';
  String get noActiveLiveStreams =>
      isZh ? '当前暂无开播中的直播间。' : 'No active live streams found.';
  String get noActiveMeetings =>
      isZh ? '当前暂无进行中的会议。' : 'No active meetings found.';
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
  String get availableChatRooms => isZh ? '可加入的聊天室' : 'Available chat rooms';
  String get noActiveChatRooms =>
      isZh ? '当前没有可加入的聊天室。' : 'No active chat rooms found.';
  String get refresh => isZh ? '刷新' : 'Refresh';
  String get noActiveRooms => isZh ? '当前没有正在进行的房间。' : 'No active rooms found.';
  String get join => isZh ? '加入' : 'Join';
  String get enterBackendUrl =>
      isZh ? '请先输入后端 URL。' : 'Enter your backend URL first.';
  String get enterRoomCode => isZh ? '请先输入房间码。' : 'Enter a room code first.';
  String get invalidRoomCode => isZh
      ? '房间码必须为 4–12 位字母或数字。'
      : 'Room code must be 4–12 letters or digits.';

  String get settings => isZh ? '设置' : 'Settings';
  String get serverAndIdentity => isZh ? '环境与身份' : 'Environment & Identity';
  String get serverAndIdentitySettings =>
      isZh ? '连接与诊断' : 'Connection & Diagnostics';
  String get done => isZh ? '完成' : 'Done';
  String get unconfigured => isZh ? '未配置' : 'Unconfigured';
  String get tapToConfigure => isZh ? '点击配置' : 'Tap to configure';
  String get copySuccess => isZh ? '已复制到剪贴板' : 'Copied to clipboard';
  String get currentIdentity => isZh ? '当前身份' : 'Current identity';
  String get copy => isZh ? '复制' : 'Copy';
  String get chatProviderLabel => isZh ? '聊天' : 'Chat';
  String get videoProviderLabel => isZh ? '视频' : 'Video';
  String backendMediaProvider(String? provider, {required bool checkingNow}) {
    if (checkingNow) {
      return isZh ? '后端视频服务商：检查中…' : 'Backend video provider: checking…';
    }
    final value = provider ?? (isZh ? '未知' : 'Unknown');
    return isZh ? '后端视频服务商：$value' : 'Backend video provider: $value';
  }

  String backendChatProvider(String? provider, {required bool checkingNow}) {
    if (checkingNow) {
      return isZh ? '后端聊天服务商：检查中…' : 'Backend chat provider: checking…';
    }
    final value = provider ?? (isZh ? '未知' : 'Unknown');
    return isZh ? '后端聊天服务商：$value' : 'Backend chat provider: $value';
  }

  String get chatProviderNotConfigured => isZh ? '未配置' : 'Not configured';

  String providerSummary({
    required bool chatTab,
    required String? mediaProvider,
    required String? chatProvider,
  }) {
    if (chatTab) {
      return '$chatProviderLabel：${chatProvider ?? chatProviderNotConfigured}';
    }
    if (mediaProvider == null) {
      return chatProvider == null ? '' : '$chatProviderLabel：$chatProvider';
    }
    final chat = chatProvider == null
        ? ''
        : ' · $chatProviderLabel：$chatProvider';
    return '$defaultServer：$mediaProvider$chat';
  }

  String chatProviderDisplayName(String providerId) =>
      switch (providerId.trim().toLowerCase()) {
        'agora-chat' => 'Agora Chat',
        'ivs-chat' => 'Amazon IVS Chat',
        'tencent-chat' => 'Tencent Chat',
        _ => providerId.trim().toUpperCase(),
      };

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
