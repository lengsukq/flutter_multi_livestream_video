import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Lightweight localization surface for the built-in SDK UI.
///
/// The SDK does not own a global locale. It follows the host application's
/// locale and can be wired into [MaterialApp] through [localizationsDelegates]
/// and [supportedLocales].
class RealtimeStrings {
  const RealtimeStrings._(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode.toLowerCase() == 'zh';

  static const supportedLocales = <Locale>[Locale('en'), Locale('zh', 'CN')];

  static const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const delegate = _RealtimeStringsDelegate();

  static RealtimeStrings of(BuildContext context) =>
      Localizations.of<RealtimeStrings>(context, RealtimeStrings) ??
      RealtimeStrings._(Localizations.localeOf(context));

  String get chat => isZh ? '聊天' : 'Chat';
  String get standaloneChat => isZh ? '独立聊天' : 'Standalone Chat';
  String get independentProductChat =>
      isZh ? '独立产品聊天' : 'Independent product chat';
  String get independentProductChatDescription => isZh
      ? '聊天可以独立于 Meeting / Live 使用，也会在与音视频组合时复用同一套 ChatSession UI。'
      : 'Chat works independently from Meeting / Live and uses the same ChatSession UI when embedded with media.';
  String get roomCode => isZh ? '房间码' : 'Room code';
  String roomLabel(String code) => isZh ? '房间 $code' : 'Room $code';
  String get displayName => isZh ? '显示名称' : 'Display name';
  String get createChatRoom => isZh ? '创建聊天室' : 'Create chat room';
  String get joinChatRoom => isZh ? '加入聊天室' : 'Join chat room';
  String get chatUser => isZh ? '聊天用户' : 'Chat user';
  String get enterChatRoomCode =>
      isZh ? '请输入聊天室房间码。' : 'Enter a chat room code.';

  String get manageRoom => isZh ? '管理房间' : 'Manage room';
  String get roomManagement => isZh ? '房间管理' : 'Room management';
  String roomManagementSubtitle(String provider, String role) =>
      isZh ? '服务商：$provider · 角色：$role' : 'Provider: $provider · Role: $role';
  String get participant => isZh ? '参与者' : 'Participant';
  String get removeParticipant => isZh ? '移除参与者' : 'Remove participant';
  String get roomMembers => isZh ? '房间成员' : 'Room members';
  String get you => isZh ? '你' : 'You';
  String get mediaOnline => isZh ? '音视频在线' : 'Media online';
  String get chatOnline => isZh ? 'Chat 在线' : 'Chat online';
  String get removeFromMedia => isZh ? '移出音视频' : 'Remove from media';
  String get removeFromChat => isZh ? '移出 Chat' : 'Remove from Chat';
  String get muteParticipant => isZh ? '静音' : 'Mute';
  String get stopParticipantVideo => isZh ? '关闭视频' : 'Stop video';
  String get unsupported => isZh ? '不支持' : 'Unsupported';
  String get noManagedMembers =>
      isZh ? '当前没有可管理的成员。' : 'No manageable members are currently present.';
  String get chatManagementUnavailable => isZh
      ? '当前 Chat Provider 不支持此管理操作。'
      : 'The current Chat provider does not support this management action.';
  String get closeRoomForEveryone =>
      isZh ? '为所有人关闭房间' : 'Close room for everyone';
  String get closeRoom => isZh ? '关闭房间' : 'Close room';

  String get leaveRoomTitle => isZh ? '离开房间？' : 'Leave room?';
  String get leaveRoomConfirmation =>
      isZh ? '确定要断开连接并离开吗？' : 'Are you sure you want to disconnect?';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get close => isZh ? '关闭' : 'Close';
  String get leave => isZh ? '离开' : 'Leave';
  String get continueLabel => isZh ? '继续' : 'Continue';
  String get runAgain => isZh ? '重新检查' : 'Run again';
  String get microphone => isZh ? '麦克风' : 'Microphone';
  String get camera => isZh ? '摄像头' : 'Camera';
  String get speaker => isZh ? '扬声器' : 'Speaker';
  String get deviceSetup => isZh ? '设备设置' : 'Device setup';
  String get cameraPreviewUnavailable => isZh
      ? '当前服务商不支持本地摄像头预览'
      : 'Local camera preview is not supported by this provider';
  String get previewStartFailed => isZh
      ? '无法启动预览，仍可继续加入。'
      : 'Preview could not start. You can still continue.';
  String get deviceListUnavailable =>
      isZh ? '设备列表暂不可用' : 'Device list is unavailable';
  String get noDevicesFound =>
      isZh ? '没有检测到可用的音视频设备' : 'No audio or video devices were found';
  String get deviceSelectionUnsupported => isZh
      ? '当前服务商不支持选择设备，可继续入会。'
      : 'Device selection is not supported by this provider. You can continue.';
  String get joinMeeting => isZh ? '加入会议' : 'Join meeting';
  String get enterLiveRoom => isZh ? '进入直播间' : 'Enter live room';
  String get connecting => isZh ? '连接中' : 'Connecting';
  String get reconnecting => isZh ? '正在重新连接' : 'Reconnecting';
  String get reconnectingDetail => isZh
      ? '正在尝试恢复音视频连接，请稍候。'
      : 'Trying to restore audio and video. Please wait.';
  String get connectionFailed => isZh ? '连接失败' : 'Connection failed';
  String get ended => isZh ? '房间已结束' : 'Room ended';
  String get participants => isZh ? '成员' : 'Participants';
  String get switchCamera => isZh ? '切换摄像头' : 'Switch camera';
  String get speakerView => isZh ? '发言人' : 'Speaker';
  String get connected => isZh ? '已连接' : 'Connected';
  String get leaveLiveRoom => isZh ? '离开直播间' : 'Leave live room';
  String get endLiveRoom => isZh ? '结束直播' : 'End live';
  String get closeLiveRoomConfirmation => isZh
      ? '结束直播会关闭房间并断开所有观众。'
      : 'Ending the live stream closes the room and disconnects all viewers.';

  String get onlyOneHere => isZh ? '现在只有你一个人' : "You're the only one here";
  String get shareRoomCode =>
      isZh ? '分享房间码即可邀请其他人加入' : 'Share the room code to start streaming';
  String get copied => isZh ? '已复制' : 'Copied';
  String copyRoom(String code) => isZh ? '复制 $code' : 'Copy $code';
  String get youSuffix => isZh ? '（你）' : ' (you)';

  String get closeChat => isZh ? '关闭聊天' : 'Close chat';
  String get noMessagesYet => isZh ? '还没有消息' : 'No messages yet';
  String messageCount(int count) => isZh ? '$count 条消息' : '$count messages';
  String get startConversation => isZh ? '开始聊天吧' : 'Start the conversation';
  String get messageHint => isZh ? '输入消息…' : 'Message…';
  String get readOnly => isZh ? '只读' : 'Read only';
  String chatState(String state) => isZh ? '聊天状态：$state' : 'Chat is $state';
  String chatConnectionState(String state) {
    if (!isZh) return state;
    return switch (state) {
      'disconnected' => '已断开',
      'connecting' => '连接中',
      'connected' => '已连接',
      'reconnecting' => '重连中',
      'failed' => '连接失败',
      'disposed' => '已结束',
      _ => state,
    };
  }

  String roleLabel(String role) {
    if (!isZh) return role;
    return switch (role) {
      'host' => '房主',
      'viewer' => '观众',
      'participant' => '参与者',
      _ => role,
    };
  }

  String get manageChat => isZh ? '管理聊天' : 'Manage chat';
  String get messageActions => isZh ? '消息操作' : 'Message actions';
  String get capabilityDependentActions => isZh
      ? '可用操作取决于当前服务商能力。'
      : 'Available actions depend on provider capabilities.';
  String get deleteMessage => isZh ? '删除消息' : 'Delete message';
  String removeUser(String name) => isZh ? '移除 $name' : 'Remove $name';
  String get chatManagement => isZh ? '聊天管理' : 'Chat management';
  String get hostOnlyActions =>
      isZh ? '仅房主可使用的管理操作' : 'Host-only control plane actions';
  String get closeChatRoom => isZh ? '关闭聊天室' : 'Close chat room';

  String get rtcData => 'RTC Data';
  String get debugDataPayload => isZh ? '调试数据内容…' : 'Debug data payload…';
  String get screenShare => isZh ? '屏幕共享' : 'Screen Share';
  String get expandStage => isZh ? '放大聚焦' : 'Expand stage';
  String get compactStage => isZh ? '紧凑模式' : 'Compact view';
  String get focusParticipant => isZh ? '置顶聚焦' : 'Spotlight';
  String get gridView => isZh ? '网格视图' : 'Grid view';
  String get randomCode => isZh ? '随机' : 'Random';
  String get paste => isZh ? '粘贴' : 'Paste';
  String get clear => isZh ? '清空' : 'Clear';

  String get preJoinCheck => isZh ? '加入前检查' : 'Pre-Join Check';
  String get runningPreJoinChecks =>
      isZh ? '正在检测设备、权限与网络连通性…' : 'Checking devices, permissions & network…';
  String get unableToRunPreJoin =>
      isZh ? '无法执行加入前检查。' : 'Unable to run the pre-join check.';
  String get readyToContinue => isZh ? '可以继续' : 'Ready to continue';
  String get resolveBlockingIssues =>
      isZh ? '请先处理阻止加入的问题' : 'Resolve blocking issues before joining';
  String get backend => isZh ? '后端' : 'Backend';
  String get provider => isZh ? '服务商' : 'Provider';
  String get microphonePermission => isZh ? '麦克风权限' : 'Microphone permission';
  String get cameraPermission => isZh ? '摄像头权限' : 'Camera permission';
  String get requestPermission => isZh ? '获取权限' : 'Grant access';
  String get openAppSettings => isZh ? '前往系统设置' : 'Open app settings';
  String get browserPermissionSettings => isZh ? '查看浏览器设置' : 'Browser settings';
  String get permissionHelpTitle =>
      isZh ? '请在浏览器中允许权限' : 'Allow access in your browser';
  String get permissionSettingsUnavailable => isZh
      ? '无法打开系统设置，请手动为应用开启权限。'
      : 'Could not open system settings. Enable this permission for the app manually.';
  String get permissionRequestFailed =>
      isZh ? '权限请求失败，请稍后重试。' : 'Permission request failed. Try again.';
  String permissionGranted(String label) =>
      isZh ? '已获得$label权限。' : '$label permission is granted.';
  String permissionDenied(String label) => isZh
      ? '尚未获得$label权限，可以点击获取权限。'
      : '$label permission is not granted. Tap to request access.';
  String permissionPermanentlyDenied(String label) => isZh
      ? '$label权限已被拒绝，请前往系统设置开启。'
      : '$label permission is blocked. Open app settings to enable it.';
  String permissionRestricted(String label) => isZh
      ? '$label权限受到系统限制。'
      : '$label permission is restricted by the system.';
  String permissionBrowserHelp(String label) => isZh
      ? '浏览器已阻止$label。请打开地址栏旁的网站权限设置并允许访问，然后返回此页重新检查。'
      : 'Your browser blocked $label. Allow it in the site permissions menu near the address bar, then return and run the check again.';
  String get microphoneDevice => isZh ? '麦克风设备' : 'Microphone device';
  String get cameraDevice => isZh ? '摄像头设备' : 'Camera device';
  String get network => isZh ? '网络' : 'Network';
  String get providerNetwork => isZh ? '服务商网络' : 'Provider network';
  String preJoinStatus(String status) {
    if (!isZh) return status.toUpperCase();
    return switch (status) {
      'passed' => '通过',
      'failed' => '失败',
      'unsupported' => '不支持',
      'unknown' => '未知',
      _ => status,
    };
  }

  String get english => 'English';
  String get chinese => '中文';
  String get language => isZh ? '语言' : 'Language';

  String get meeting => isZh ? '会议' : 'Meeting';
  String get live => isZh ? '直播' : 'Live';
  String get meetingModeSubtitle =>
      isZh ? '参与者共同发布音视频' : 'Co-publish audio & video';
  String get liveModeSubtitle => isZh ? '主播与观众' : 'Host stage + viewers';
  String get meetingModeDescription => isZh
      ? '所有人以参与者身份加入，并可控制发布音视频。'
      : 'Everyone joins as a participant with publish controls.';
  String get liveModeDescription => isZh
      ? '创建者为主播，其他设备以观众身份加入。'
      : 'The creator is the host; other devices join as viewers.';
  String roomSummary(String mode, String provider, int attendees) => isZh
      ? '$mode · $provider · $attendees 人在线'
      : '$mode · $provider · $attendees online';
  String roomCardSummary(String mode, int attendees) =>
      isZh ? '$mode · $attendees 人在线' : '$mode · $attendees online';
  String get join => isZh ? '加入' : 'Join';
}

class _RealtimeStringsDelegate extends LocalizationsDelegate<RealtimeStrings> {
  const _RealtimeStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';

  @override
  Future<RealtimeStrings> load(Locale locale) =>
      SynchronousFuture<RealtimeStrings>(RealtimeStrings._(locale));

  @override
  bool shouldReload(_RealtimeStringsDelegate old) => false;
}
