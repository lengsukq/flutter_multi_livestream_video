export type DemoLanguage = 'zh' | 'en';

const chineseMessages: Record<string, string> = {
  'Admin actions must come from this site.': '管理操作必须来自本站。',
  'Set MEDIA_ADMIN_PASSWORD before using admin routes.': '使用管理接口前，请先设置 MEDIA_ADMIN_PASSWORD。',
  'Sign in to manage this service.': '请登录后管理此服务。',
  'The media connection service is paused.': '媒体连接服务已暂停。',
  'A valid demo bearer token is required.': '需要有效的 Demo Bearer Token。',
  'The requested chat room was not found.': '未找到请求的聊天室。',
  'Unable to close the chat room.': '无法关闭聊天室。',
  'Unable to refresh chat credentials.': '无法刷新聊天凭证。',
  'The chat room code is already in use.': '聊天室编号已被占用。',
  'Unable to create the chat room.': '无法创建聊天室。',
  'Unable to join the chat room.': '无法加入聊天室。',
  'This demo server supports backend contract v1.': '此 Demo 后端支持的接口协议版本为 v1。',
  'Admin login is not configured.': '尚未配置管理登录。',
  'The management password is incorrect.': '管理密码不正确。',
  'Set MEDIA_DEFAULT_PROVIDER in Vercel and redeploy to change the default provider.': '如需更改默认媒体服务，请在 Vercel 中设置 MEDIA_DEFAULT_PROVIDER 并重新部署。',
  'roomCode must be 4-12 letters/digits.': 'roomCode 必须为 4–12 位字母或数字。',
  'The room code is already in use.': '房间号已被占用。',
  'role must be participant, host, or viewer.': 'role 必须是 participant、host 或 viewer。',
  'roomMode must be meeting or broadcast.': 'roomMode 必须是 meeting 或 broadcast。',
  'Unable to create the room.': '无法创建房间。',
  'The requested room was not found.': '未找到请求的房间。',
  'displayName or userId is required.': '必须提供 displayName 或 userId。',
  'Unable to join the room.': '无法加入房间。',
  'Unable to issue chat credentials.': '无法签发聊天凭证。',
  'participantId is required.': '必须提供 participantId。',
  'Unable to refresh provider credentials.': '无法刷新服务提供方凭证。',
  'Host permission is required.': '需要主持人权限。',
  'targetParticipantId is required.': '必须提供 targetParticipantId。',
  'Use leave or closeRoom for the host.': '主持人请使用 leave 或 closeRoom。',
  'Participant was not found.': '未找到该参与者。',
  'Unable to remove the participant.': '无法移除该参与者。',
  'Unable to close the room.': '无法关闭房间。',
  'A room with the requested code already exists.': '请求的房间号已存在。',
  'The requested room mode is not supported by this provider.': '此服务提供方不支持请求的房间模式。',
  'The requested role is not supported by this provider.': '此服务提供方不支持请求的角色。',
  'The requested provider feature is not supported.': '此服务提供方不支持请求的功能。',
  'Unsupported media provider': '不支持的媒体服务提供方',
  'Unsupported chat provider': '不支持的聊天服务提供方',
  'LiveKit is not configured.': '尚未配置 LiveKit。',
  'Amazon IVS Real-Time is not configured.': '尚未配置 Amazon IVS Real-Time。',
  'ARTC is not configured. Set ARTC_APP_ID and ARTC_APP_KEY.': '尚未配置 ARTC。请设置 ARTC_APP_ID 和 ARTC_APP_KEY。',
  'Agora is not configured. Set AGORA_APP_ID and AGORA_APP_CERTIFICATE.': '尚未配置 Agora。请设置 AGORA_APP_ID 和 AGORA_APP_CERTIFICATE。',
  'TRTC is not configured. Set TRTC_SDK_APP_ID and TRTC_SDK_SECRET_KEY.': '尚未配置 TRTC。请设置 TRTC_SDK_APP_ID 和 TRTC_SDK_SECRET_KEY。',
  'Set LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET.': '请设置 LIVEKIT_URL、LIVEKIT_API_KEY 和 LIVEKIT_API_SECRET。',
  'Set TENCENT_CHAT_SDK_APP_ID and TENCENT_CHAT_SECRET_KEY.': '请设置 TENCENT_CHAT_SDK_APP_ID 和 TENCENT_CHAT_SECRET_KEY。',
  'Set AGORA_CHAT_APP_KEY, AGORA_CHAT_REST_HOST, AGORA_CHAT_APP_ID, and AGORA_CHAT_APP_CERTIFICATE.': '请设置 AGORA_CHAT_APP_KEY、AGORA_CHAT_REST_HOST、AGORA_CHAT_APP_ID 和 AGORA_CHAT_APP_CERTIFICATE。',
  'Select a configured chat provider before creating a chat room.': '创建聊天室前，请先选择已完成配置的聊天服务。',
  'role is assigned by roomMode; meeting rooms are created as participant.': '角色由 roomMode 决定；meeting 房间会以 participant 角色创建。',
  'role is assigned by roomMode; broadcast rooms are created as host.': '角色由 roomMode 决定；broadcast 房间会以 host 角色创建。',
  'deviceId must be 8-128 letters, digits, dots, underscores, colons, or hyphens.': 'deviceId 必须为 8–128 位字母、数字、点、下划线、冒号或连字符。',
  'The room is partially closed and is waiting for cleanup retry.': '房间正在关闭，等待系统重试清理。',
  'The room is partially closed and cannot issue chat credentials.': '房间正在关闭，暂时无法签发聊天凭证。',
  'This room does not have a chat provider.': '此房间未配置聊天服务。',
  'The room is partially closed and cannot refresh credentials.': '房间正在关闭，暂时无法刷新凭证。',
  'Credential refresh cannot change the participant role.': '刷新凭证时不能更改参与者角色。',
  'Credential refresh is not supported by this room provider.': '此房间的服务提供方不支持刷新凭证。',
  'The participant is no longer registered in this room.': '该参与者已不在此房间中。',
  'This provider does not support server-enforced participant removal.': '此服务提供方不支持由服务器强制移除参与者。',
  'The participant is not in this room.': '该参与者不在此房间中。',
  'The participant is not authorized to refresh credentials for this room and role.': '该参与者无权在此房间和角色下刷新凭证。',
  'The role does not match this TRTC room scene.': '参与者角色与 TRTC 房间场景不匹配。',
  'Chat token requires a stable participant identity.': '聊天凭证需要稳定的参与者身份。',
  'Tencent Chat requires a stable participant identity.': 'Tencent Chat 需要稳定的参与者身份。',
  'Tencent Chat did not return a group ID after creation.': 'Tencent Chat 创建后未返回群组 ID。',
  'Agora Chat did not return a user UUID after registration.': 'Agora Chat 注册后未返回用户 UUID。',
  'Agora Chat did not return a chat room id.': 'Agora Chat 创建后未返回聊天室 ID。',
  'This provider does not support the requested room mode.': '此服务提供方不支持请求的房间模式。',
  'This provider does not support the requested role.': '此服务提供方不支持请求的角色。',
  'LiveKit is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET.': '尚未配置 LiveKit。请设置 LIVEKIT_URL、LIVEKIT_API_KEY 和 LIVEKIT_API_SECRET。',
  'ARTC_TOKEN_TTL_SECONDS must be between 60 and 86400.': 'ARTC_TOKEN_TTL_SECONDS 必须在 60–86400 秒之间。',
  'Agora App ID and App Certificate are required.': '必须提供 Agora App ID 和 App Certificate。',
  'Amazon IVS Real-Time is not configured. Set IVS_REALTIME_REGION (or AWS_REGION) and provide AWS credentials through the server IAM credential chain.': '尚未配置 Amazon IVS Real-Time。请设置 IVS_REALTIME_REGION（或 AWS_REGION），并通过服务器 IAM 凭证链提供 AWS 凭证。',
  'Amazon IVS Chat is not configured. Set an AWS region through IVS_CHAT_REGION, AWS_REGION, AWS_DEFAULT_REGION, or the active AWS profile, and provide AWS credentials through the server IAM credential chain.': '尚未配置 Amazon IVS Chat。请通过 IVS_CHAT_REGION、AWS_REGION、AWS_DEFAULT_REGION 或当前 AWS profile 设置区域，并通过服务器 IAM 凭证链提供 AWS 凭证。',
  'Amazon IVS Chat is not configured.': '尚未配置 Amazon IVS Chat。',
  'Tencent Chat is not configured. Set TENCENT_CHAT_SDK_APP_ID and TENCENT_CHAT_SECRET_KEY; TENCENT_CHAT_ADMIN_USER defaults to administrator.': '尚未配置 Tencent Chat。请设置 TENCENT_CHAT_SDK_APP_ID 和 TENCENT_CHAT_SECRET_KEY；TENCENT_CHAT_ADMIN_USER 默认为 administrator。',
  'Agora Chat is not configured. Set AGORA_CHAT_APP_KEY, AGORA_CHAT_REST_HOST, and AGORA_CHAT_APP_ID/AGORA_CHAT_APP_CERTIFICATE (or reuse AGORA_APP_ID/AGORA_APP_CERTIFICATE).': '尚未配置 Agora Chat。请设置 AGORA_CHAT_APP_KEY、AGORA_CHAT_REST_HOST 和 AGORA_CHAT_APP_ID/AGORA_CHAT_APP_CERTIFICATE（或复用 AGORA_APP_ID/AGORA_APP_CERTIFICATE）。',
  'AGORA_CHAT_APP_KEY must be the Agora Chat App Key in OrgName#AppName format. Do not use the numeric Agora RTC App ID.': 'AGORA_CHAT_APP_KEY 格式错误。请使用 Agora Chat 的 App Key（OrgName#AppName），不要填写纯数字的 Agora RTC App ID。',
};

export function resolveDemoLanguage(acceptLanguage: string | undefined): DemoLanguage {
  if (!acceptLanguage) return 'en';

  const preferred = acceptLanguage
    .split(',')
    .map((part) => {
      const [tag, quality] = part.trim().split(';q=');
      return { tag: tag?.toLowerCase() ?? '', quality: Number(quality ?? 1) };
    })
    .filter((item) => item.tag && Number.isFinite(item.quality))
    .sort((a, b) => b.quality - a.quality);

  const firstChoice = preferred.find((item) => item.quality > 0);
  return firstChoice?.tag === 'zh' || firstChoice?.tag.startsWith('zh-')
    ? 'zh'
    : 'en';
}

export function localizeDemoMessage(message: string, language: DemoLanguage): string {
  if (language === 'en') return message;
  const direct = chineseMessages[message];
  if (direct) return direct;

  const unsupportedProvider = message.match(/^Unsupported (media|chat) provider "(.+)"\.$/);
  if (unsupportedProvider) {
    const kind = unsupportedProvider[1] === 'media' ? '媒体' : '聊天';
    return `不支持的${kind}服务提供方“${unsupportedProvider[2]}”。`;
  }

  const contractVersion = message.match(/^This demo server supports backend contract v(.+)\.$/);
  if (contractVersion) return `此 Demo 后端支持的接口协议版本为 v${contractVersion[1]}。`;

  const trtcRoleError = message.match(/^This TRTC room uses the (.+) scene and does not support (.+)\.$/);
  if (trtcRoleError) {
    return `TRTC 房间使用 ${trtcRoleError[1]} 场景，不支持 ${trtcRoleError[2]}。`;
  }

  const artcRoleError = message.match(/^This ARTC room uses the (.+) mode and does not support (.+)\.$/);
  if (artcRoleError) {
    return `ARTC 房间使用 ${artcRoleError[1]} 模式，不支持 ${artcRoleError[2]}。`;
  }

  const providerOperation = message.match(/^(Amazon IVS (?:Real-Time|Chat)) (.+) failed\.$/);
  if (providerOperation) return `${providerOperation[1]} 操作失败：${providerOperation[2]}。`;

  const providerRestError = message.match(/^(Tencent Chat|Agora Chat) REST request failed: (.+)$/);
  if (providerRestError) return `${providerRestError[1]} REST 请求失败：${providerRestError[2]}`;

  return message;
}
