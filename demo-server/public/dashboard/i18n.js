
const translationPairs = [
      ['语言', 'Language'], ['中文', 'Chinese'],
      ['Media Live Console · 智能直播控制台', 'Media Live Console · Smart Live Console'],
      ['管理台登录', 'Dashboard Login'],
      ['输入服务端配置的管理密码。登录成功后会签发仅供本机管理台使用的安全 Cookie。', 'Enter the admin password configured on the server. A secure cookie for this dashboard will be issued after sign-in.'],
      ['管理密码', 'Admin password'], ['登录', 'Sign in'], ['登录中…', 'Signing in…'],
      ['确认强制关闭房间？', 'Force close this room?'],
      ['此操作会立即断开所有在线成员连接，销毁云端推拉流通道并停止计费。', 'This immediately disconnects everyone, removes the cloud media session, and stops further billing.'],
      ['取消', 'Cancel'], ['确认关闭', 'Confirm close'], ['能力说明', 'Capability details'],
      ['能力', 'Capability'], ['状态', 'Status'], ['暂无额外说明。', 'No additional details.'], ['知道了', 'Done'],
      ['检查中', 'Checking…'], ['正在拉取节点拓扑...', 'Loading service topology…'],
      ['Region: us-east-1 / ap-southeast-1', 'Regions: us-east-1 / ap-southeast-1'],
      ['刷新', 'Refresh'], ['退出', 'Sign out'], ['正在读取连接服务状态…', 'Checking connection service status…'],
      ['新房间媒体引擎调度', 'Media provider for new rooms'],
      ['控制端动态切换后续新建房间绑定的云厂商底层通道。已创建房间会始终沿用各自创建时的通道，互不干扰。', 'Choose the media provider for new rooms. Existing rooms stay with the provider selected when they were created.'],
      ['当前 SDK 能力矩阵', 'SDK capability matrix'],
      ['展示本项目当前 adapter 能力，而不是厂商服务的理论全集；将鼠标悬停在单元格上可查看限制。', 'Shows the capabilities exposed by this project’s adapters, not every capability offered by each vendor. Hover over a cell for limitations.'],
      ['能力状态图例', 'Capability status legend'], ['支持', 'Supported'], ['有条件', 'Conditional'], ['不支持', 'Not supported'],
      ['新房间聊天服务调度', 'Chat provider for new rooms'],
      ['聊天与音视频独立选择。关闭 Chat 时仍可使用媒体 Provider 自带的 RTC Data 作为调试能力，但不会作为产品聊天。', 'Chat and media providers are selected independently. Disabling Chat leaves provider RTC Data available for debugging, but does not provide product chat.'],
      ['Chat 能力矩阵', 'Chat capability matrix'],
      ['展示当前 Chat adapter 真正暴露给 ChatSession 的能力；“有条件”旁的 ? 可查看具体限制。', 'Shows the capabilities exposed to ChatSession by the current Chat adapter. Select ? beside Conditional for details.'],
      ['Chat 能力状态图例', 'Chat capability status legend'],
      ['独立聊天室', 'Standalone chat rooms'],
      ['Chat 可独立于 Meeting / Live 使用，也可继续作为音视频房间的 Attached Chat。新建独立聊天室使用上方当前 Chat Provider。', 'Chat can run independently or be attached to a Meeting or Live room. New standalone chat rooms use the selected Chat provider above.'],
      ['独立 Chat 参与者', 'Standalone chat participants'], ['独立聊天室会话', 'Standalone chat sessions'],
      ['房间号 / 云端群 ID', 'Room code / Cloud group ID'], ['聊天服务提供方', 'Chat Provider'], ['云端成员数', 'Cloud members'], ['创建时间', 'Created'], ['管理操作', 'Actions'],
      ['本地已关联', 'Tracked locally'], ['云端遗留', 'Cloud orphan'], ['复制云端群 ID', 'Copy cloud group ID'],
      ['当前暂无云端聊天室', 'No cloud chat rooms found'],
      ['可在 Flutter Demo 的“独立聊天”入口创建。', 'Create one from the “Standalone Chat” entry in the Flutter demo.'],
      ['当前表格直接读取所选 Chat Provider 的云端聊天室；Tencent Chat 仅展示本 Demo 创建的 Realtime room / 历史 rm_ 群。', 'This table reads cloud rooms directly from the selected Chat provider. For Tencent Chat, only Realtime room groups and legacy rm_ groups created by this demo are shown.'],
      ['云端聊天室 {code} 已删除', 'Cloud chat room {code} was deleted'],
      ['删除云端聊天室失败: {message}', 'Could not delete cloud chat room: {message}'],
      ['当前暂无独立聊天室', 'No standalone chat rooms yet'], ['活跃房间总数', 'Active rooms'],
      ['当前维持心跳连接中的会议室', 'Rooms with an active heartbeat'], ['当前参会人次', 'Connected participants'],
      ['已签发且在线的流媒体参与者', 'Issued credentials with an active media connection'], ['默认接入通道', 'Default media provider'],
      ['随控制台无缝切流', 'Switch providers from this dashboard'], ['服务持续运行', 'Service uptime'], ['服务已平稳启动', 'Service started successfully'],
      ['房间号（4-12位数字/字母，留空系统随机分配）', 'Room code (4–12 letters or digits; leave blank to generate one)'],
      ['随机生成一个房间号', 'Generate a random room code'],
      ['🎲 随机', '🎲 Generate'], ['创建房间', 'Create room'], ['5 秒自动同步监控状态', 'Monitoring refreshes every 5 seconds'],
      ['实时房间会话', 'Live room sessions'], ['搜索房间号 / 成员...', 'Search room code or member…'],
      ['房间号 / 标识', 'Room code / ID'], ['通道 Provider', 'Media provider'], ['在线人数', 'Online'], ['参会成员', 'Participants'], ['心跳 / 状态', 'Heartbeat / status'],
      ['当前暂无活跃房间，可通过上方快速创建', 'No active rooms. Create one above.'], ['系统事件审计流', 'System event log'],
      ['全部', 'All'], ['创建', 'Created'], ['加入', 'Joined'], ['离开', 'Left'], ['已关闭', 'Closed'], ['关闭', 'Close'],
      ['日志数据初始化中...', 'Loading event log…'], ['暂无对应事件流记录', 'No matching events'],
      ['没有找到符合条件的房间', 'No rooms match your search'], ['活跃在线', 'Online'], ['无在线成员', 'No online members'], ['暂无成员', 'No members yet'],
      ['复制房号', 'Copy room code'], ['分享链接', 'Share link'],
      ['当前暂无独立聊天室。可在 Flutter Demo 的“独立聊天”入口创建。', 'No standalone chat rooms. Create one from the “Standalone Chat” entry in the Flutter demo.'],
      ['登录已过期，请重新登录。', 'Your session expired. Please sign in again.'], ['已退出登录', 'You have signed out'],
      ['管理登录尚未配置，请在服务端设置 MEDIA_ADMIN_PASSWORD。', 'Admin login is not configured. Set MEDIA_ADMIN_PASSWORD on the server.'],
      ['请输入管理密码登录。', 'Enter the admin password to sign in.'],
      ['关闭 Chat', 'Disable Chat'], ['不为新房间创建产品聊天服务', 'Do not create a product chat service for new rooms'],
      ['当前使用', 'In use'], ['可选择', 'Available'], ['未配置', 'Not configured'],
      ['暂无 Media Provider 能力元数据', 'No Media provider capability metadata'], ['暂无 Chat Provider 能力元数据', 'No Chat provider capability metadata'],
      ['新房间媒体通道已切换为 <b>{label}</b>', 'Media provider for new rooms changed to <b>{label}</b>'],
      ['Provider 切换失败: {message}', 'Could not switch provider: {message}'],
      ['新房间聊天服务已切换为 <b>{label}</b>', 'Chat provider for new rooms changed to <b>{label}</b>'],
      ['新房间产品聊天已关闭', 'Product chat for new rooms is disabled'],
      ['Chat Provider 切换失败: {message}', 'Could not switch Chat provider: {message}'],
      ['线上 Provider 由 MEDIA_DEFAULT_PROVIDER 环境变量配置', 'The production provider is configured by MEDIA_DEFAULT_PROVIDER'],
      ['新房间使用 {provider}', 'New rooms will use {provider}'], ['新房间不创建产品聊天服务', 'New rooms will not get a product chat service'],
      [' 的配置要求', ' configuration requirements'], [' 的能力说明', ' capability details'],
      ['连接服务开启', 'Connections enabled'], ['连接服务已暂停', 'Connections paused'], ['连接服务已开启。', 'Connections are enabled.'], ['连接服务已暂停。', 'Connections are paused.'],
      ['线上默认通道由 Vercel 的 MEDIA_DEFAULT_PROVIDER 环境变量决定；修改后需重新部署。', 'The default production provider comes from MEDIA_DEFAULT_PROVIDER in Vercel. Redeploy after changing it.'],
      ['聊天与音视频独立选择。切换只影响后续新建房间；关闭 Chat 时不会创建产品聊天服务。Vercel Function 的选择只保存在当前实例，实例重启后会回到 CHAT_DEFAULT_PROVIDER（未设置则关闭），不同实例间也不会同步。', 'Chat and media providers are selected independently. Changes affect new rooms only. Disabling Chat prevents product chat from being created. On Vercel, the selection is local to this function instance and resets to CHAT_DEFAULT_PROVIDER (or disabled) after restart; instances do not share the selection.'],
      ['启动于 {time}', 'Started at {time}'], ['刷新数据失败: {message}', 'Could not refresh data: {message}'],
      ['✨ 房间 <b>{code}</b> 已成功创建', '✨ Room <b>{code}</b> created'], ['创建房间失败: {message}', 'Could not create room: {message}'],
      ['强制关闭房间 {code}？', 'Force close room {code}?'],
      ['确认关闭房间 {code}？此操作将立即断开所有在线成员的音视频连接并清理云端会话。', 'Close room {code}? This immediately disconnects all participants and removes the cloud session.'],
      ['关闭独立聊天室 {code}？', 'Close standalone chat room {code}?'],
      ['确认关闭独立聊天室 {code}？此操作会清理对应 Chat Provider 的云端聊天室，并让现有客户端失去该聊天室连接。', 'Close standalone chat room {code}? This removes the cloud chat room and disconnects its current clients.'],
      ['房间 {code} 已强制关闭', 'Room {code} was force closed'], ['关闭房间失败: {message}', 'Could not close room: {message}'],
      ['独立聊天室 {code} 已关闭', 'Standalone chat room {code} was closed'], ['关闭独立聊天室失败: {message}', 'Could not close standalone chat room: {message}'],
      ['已复制房间号 <b>{code}</b> 到剪贴板', 'Copied room code <b>{code}</b> to clipboard'], ['房间号: {code}', 'Room code: {code}'],
      ['已复制入会深度链接到剪贴板', 'Copied join link to clipboard'], ['链接: {link}', 'Link: {link}'],
      ['加入时间: {time}{role}', 'Joined: {time}{role}'], [' · 设备: {device}', ' · Device: {device}'],
      ['{seconds}s 前心跳', 'Heartbeat {seconds}s ago'], ['能力', 'Capability'], ['配置要求', 'Configuration'],
      ['会议模式', 'Meeting mode'], ['直播主持', 'Live host'], ['直播观看', 'Live viewer'], ['麦克风发布', 'Publish microphone'],
      ['摄像头发布', 'Publish camera'], ['屏幕共享', 'Screen sharing'], ['RTC Data 发送', 'Send RTC Data'], ['RTC Data 接收', 'Receive RTC Data'],
      ['Web 音视频', 'Web audio/video'], ['凭证自动刷新', 'Automatic credential refresh'], ['主持人移除成员', 'Host removes participants'], ['主持人关闭房间', 'Host closes room'],
      ['发送消息', 'Send message'], ['删除消息', 'Delete message'], ['成员列表', 'Member list'], ['关闭聊天室', 'Close room'],
      ['禁言成员', 'Mute member'], ['封禁成员', 'Ban member'], ['管理角色', 'Manage roles'], ['移除用户', 'Remove user'], ['服务端历史记录', 'Server history'],
      ['meeting participant / live host 可发布，viewer 仅订阅。', 'Meeting participants and live hosts can publish; viewers can only subscribe.'],
      ['participant / host 可发布，viewer 仅订阅。', 'Participants and hosts can publish; viewers can only subscribe.'],
      ['participant / host 可发送，viewer 仅接收。', 'Participants and hosts can send; viewers can only receive.'],
      ['当前 Web Bridge 支持；原生 Flutter adapter 暂未暴露。', 'Available in the Web bridge; the native Flutter adapter does not expose it yet.'],
      ['Web Bridge 支持内容共享；当前原生 Flutter Chime adapter 未暴露该能力。', 'The Web bridge supports content sharing; the native Flutter Chime adapter does not expose it yet.'],
      ['Web Bridge 支持，但角色仍仅限 participant。', 'Available in the Web bridge, but roles are limited to participants.'], ['当前没有 host 角色控制面。', 'There is no host role control plane yet.'],
      ['通过阿里云 Web SDK Bridge 接入。', 'Uses the Alibaba Cloud Web SDK bridge.'], ['通过官方 Agora Web SDK Bridge 接入。', 'Uses the official Agora Web SDK bridge.'],
      ['通过官方 TRTC Web SDK Bridge 接入。', 'Uses the official TRTC Web SDK bridge.'], ['通过 Amazon IVS Web Broadcast SDK Bridge 接入。', 'Uses the Amazon IVS Web Broadcast SDK bridge.'],
      ['媒体服务调度', 'Media Provider Routing'], ['聊天服务调度', 'Chat Provider Routing'], ['独立聊天', 'Standalone Chat'], ['服务提供方', 'Provider'],
      ['host 可关闭当前逻辑房间。', 'The host can close the logical room.'], ['host 可移除远端成员。', 'The host can remove remote participants.'],
      ['host 可关闭房间。', 'The host can close the room.'], ['host 可通过 IVS DisconnectParticipant 移除成员。', 'The host can remove participants with IVS DisconnectParticipant.'],
      ['host 具备 SDK 房间关闭能力；服务端房间为逻辑房间。', 'The host can close the SDK room; the server room is logical.'],
      ['participant / host 支持；移动 Web 浏览器受 LiveKit SDK 限制。', 'Supported for participants and hosts; mobile browsers are limited by the LiveKit SDK.'],
      ['当前后端仅开放 participant 会议房间。', 'The current backend only exposes participant meeting rooms.'],
      ['AWS Meeting 通过 Amazon Chime SDK 提供会议能力。', 'AWS Meeting routes to Amazon Chime SDK.'],
      ['AWS Live 将主持人和嘉宾接入 Amazon IVS Real-Time Publisher。', 'AWS Live routes hosts/guests to Amazon IVS Real-Time publishers.'],
      ['AWS Live 观众通过 Amazon IVS Real-Time 订阅媒体，不发布本地媒体。', 'AWS Live viewers subscribe through Amazon IVS Real-Time without publishing local media.'],
      ['AWS Meeting routes to Amazon Chime SDK; Live uses Amazon IVS Real-Time.', 'AWS Meeting uses Amazon Chime SDK; Live uses Amazon IVS Real-Time.'],
      ['Amazon Chime 媒体面', 'Amazon Chime media plane'], ['阿里云实时音视频与互动直播', 'Alibaba Cloud real-time audio/video and interactive live streaming'],
      ['腾讯云 TRTC 实时音视频', 'Tencent Cloud TRTC real-time audio/video'], ['Agora RTC 全球实时网络', 'Agora RTC global real-time network'],
      ['WebRTC 原生流集群', 'Native WebRTC streaming cluster'], ['阿里云 ARTC', 'Alibaba Cloud ARTC'], ['AWS Chime SDK', 'AWS Chime SDK'], ['Agora RTC', 'Agora RTC'],
      ['关闭 Chat', 'Disable Chat'], ['AWS managed realtime chat', 'AWS managed real-time chat'],
      ['Tencent Cloud managed persistent group chat', 'Tencent Cloud managed persistent group chat'], ['Agora managed persistent chat rooms', 'Agora managed persistent chat rooms'],
      ['可由包含 IVS DELETE_MESSAGE 能力的主持人凭证使用。', 'Available to host credentials with the IVS DELETE_MESSAGE capability.'],
      ['独立 Demo 房间会向主持人显示经过身份验证的逻辑成员列表。', 'Standalone demo rooms expose the authenticated logical member list to the host.'],
      ['独立房间主持人通过控制面关闭服务提供方房间。', 'The standalone room host closes the provider room through the control plane.'],
      ['当前 adapter 的 IVS Chat Token 能力不支持服务端强制单人禁言。', 'IVS Chat token capabilities do not provide provider-enforced per-member mute in this adapter.'],
      ['尚未实现重新加入拦截；断开连接与封禁是不同操作。', 'Rejoin blocking is not implemented; disconnect and ban are intentionally distinct.'],
      ['更改角色需要重新签发凭证，当前不会模拟此操作。', 'Role changes require issuing new credentials and are not emulated.'],
      ['当前通用 adapter 未开放 Tencent 的内容管理操作。', 'The current provider-neutral adapter does not expose Tencent moderation operations.'],
      ['当前通用 Tencent adapter 未开放此功能。', 'Not exposed by the current provider-neutral Tencent adapter.'],
      ['当前通用 adapter 未开放 Agora 的内容管理操作。', 'The current provider-neutral adapter does not expose Agora moderation operations.'],
      ['当前通用 Agora adapter 未开放此功能。', 'Not exposed by the current provider-neutral Agora adapter.'],
      ['当前 IVS Chat adapter 只保留本次会话中的消息状态。', 'The current IVS Chat adapter keeps only session-local message state.'],
      ['Tencent Chat 会保存群消息，但 Core v1 尚未在 ChatSession 中提供历史消息分页。', 'Tencent Chat persists group messages, but ChatSession history pagination is not part of Core v1.'],
      ['Agora Chat 支持服务端历史记录，但 Core v1 尚未在 ChatSession 中提供历史消息分页。', 'Agora Chat supports server history, but ChatSession history pagination is not part of Core v1.'],
      ['新房间角色由 roomMode 自动分配', 'Room roles are assigned automatically from roomMode'],
      ['查看 {provider} 的配置要求', 'View {provider} configuration requirements'],
      ['查看 {provider} {capability} 的能力说明', 'View {provider} {capability} capability details'],
      ['{provider} 尚未完成服务端配置', '{provider} is not configured on the server'],
      ['Chat Off', 'Chat disabled'], ['Unknown', 'Unknown'],
      ['尚未配置 LiveKit。请设置 LIVEKIT_URL、LIVEKIT_API_KEY 和 LIVEKIT_API_SECRET。', 'LiveKit is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET.'],
      ['尚未配置 ARTC。请设置 ARTC_APP_ID 和 ARTC_APP_KEY。', 'ARTC is not configured. Set ARTC_APP_ID and ARTC_APP_KEY.'],
      ['尚未配置 Agora。请设置 AGORA_APP_ID 和 AGORA_APP_CERTIFICATE。', 'Agora is not configured. Set AGORA_APP_ID and AGORA_APP_CERTIFICATE.'],
      ['尚未配置 TRTC。请设置 TRTC_SDK_APP_ID 和 TRTC_SDK_SECRET_KEY。', 'TRTC is not configured. Set TRTC_SDK_APP_ID and TRTC_SDK_SECRET_KEY.'],
      ['ARTC_TOKEN_TTL_SECONDS 必须在 60–86400 秒之间。', 'ARTC_TOKEN_TTL_SECONDS must be between 60 and 86400.'],
      ['尚未配置 Amazon IVS Real-Time。请设置 IVS_REALTIME_REGION（或 AWS_REGION），并通过服务器 IAM 凭证链提供 AWS 凭证。', 'Amazon IVS Real-Time is not configured. Set IVS_REALTIME_REGION (or AWS_REGION) and provide AWS credentials through the server IAM credential chain.'],
      ['尚未配置 Amazon IVS Chat。请设置 AWS 区域和服务器 IAM 凭证。', 'Amazon IVS Chat is not configured. Set an AWS region and provide credentials through the server IAM credential chain.'],
      ['尚未配置 Tencent Chat。请设置 TENCENT_CHAT_SDK_APP_ID 和 TENCENT_CHAT_SECRET_KEY。', 'Tencent Chat is not configured. Set TENCENT_CHAT_SDK_APP_ID and TENCENT_CHAT_SECRET_KEY.'],
      ['尚未配置 Agora Chat。请设置聊天服务密钥、REST 地址和 App ID/Certificate。', 'Agora Chat is not configured. Set its app key, REST host, App ID, and certificate.'],
      ['AWS Meeting 使用 Amazon Chime SDK；Live 使用 Amazon IVS Real-Time。', 'Meeting uses Amazon Chime SDK; Live uses Amazon IVS Real-Time.'],
      ['AWS WebRTC 实时 Stage', 'AWS WebRTC real-time stage'],
      ['AWS 托管实时聊天', 'AWS managed realtime chat'], ['腾讯云托管持久群聊', 'Tencent Cloud managed persistent group chat'],
      ['Agora 托管持久聊天室', 'Agora managed persistent chat rooms'],
      ['关闭 Chat', 'Disable Chat'],
      ['Chat 已关闭', 'Chat disabled'],
      ['LiveKit 尚未配置。请设置 LIVEKIT_URL、LIVEKIT_API_KEY 和 LIVEKIT_API_SECRET。', 'LiveKit is not configured. Set LIVEKIT_URL, LIVEKIT_API_KEY, and LIVEKIT_API_SECRET.'],
      ['尚未配置 Amazon IVS Real-Time。请设置 IVS_REALTIME_REGION（或 AWS_REGION）并通过服务器 IAM 凭证链提供 AWS 凭证。', 'Amazon IVS Real-Time is not configured. Set IVS_REALTIME_REGION (or AWS_REGION) and provide AWS credentials through the server IAM credential chain.'],
      ['尚未配置 Amazon IVS Chat。请设置 IVS_CHAT_REGION 或 AWS 区域，并通过服务器 IAM 凭证链提供 AWS 凭证。', 'Amazon IVS Chat is not configured. Set IVS_CHAT_REGION (or an AWS region) and provide AWS credentials through the server IAM credential chain.'],
      ['尚未配置 Tencent Chat。请设置 TENCENT_CHAT_SDK_APP_ID 和 TENCENT_CHAT_SECRET_KEY；TENCENT_CHAT_ADMIN_USER 默认为 administrator。', 'Tencent Chat is not configured. Set TENCENT_CHAT_SDK_APP_ID and TENCENT_CHAT_SECRET_KEY; TENCENT_CHAT_ADMIN_USER defaults to administrator.'],
      ['尚未配置 Agora Chat。请设置 AGORA_CHAT_APP_KEY、AGORA_CHAT_REST_HOST 和 AGORA_CHAT_APP_ID/AGORA_CHAT_APP_CERTIFICATE（或复用 AGORA_APP_ID/AGORA_APP_CERTIFICATE）。', 'Agora Chat is not configured. Set AGORA_CHAT_APP_KEY, AGORA_CHAT_REST_HOST, and AGORA_CHAT_APP_ID/AGORA_CHAT_APP_CERTIFICATE (or reuse AGORA_APP_ID/AGORA_APP_CERTIFICATE).'],
      ['AGORA_CHAT_APP_KEY 格式错误。请使用 Agora Chat 的 App Key（OrgName#AppName），不要填写纯数字的 Agora RTC App ID。', 'AGORA_CHAT_APP_KEY must be the Agora Chat App Key in OrgName#AppName format. Do not use the numeric Agora RTC App ID.'],
      ['已签发凭证的 IVS DISCONNECT_USER 权限可使用此功能。', 'Available to host credentials with the IVS DISCONNECT_USER capability.'],
      ['Amazon IVS Chat 只在当前会话中保留消息状态。', 'The current IVS Chat adapter keeps only session-local message state.'],
      ['Amazon IVS Chat 是 AWS 托管实时聊天服务', 'AWS managed realtime chat'],
      ['Tencent Cloud 托管持久群聊服务', 'Tencent Cloud managed persistent group chat'],
      ['Agora 托管持久聊天室服务', 'Agora managed persistent chat rooms'],
      ['AWS Meeting 使用 Amazon Chime SDK，Live 使用 Amazon IVS Real-Time。', 'Meeting uses Amazon Chime SDK; Live uses Amazon IVS Real-Time.'],
      ['⏱ {hours} 小时 {minutes} 分钟', '{hours}h {minutes}m'],
      ['{minutes} 分钟', '{minutes} min'],
      ['🟢 活跃在线', '🟢 Online'],
      ['<strong>连接服务已开启。</strong> 如需暂停公网入会，请在 Vercel 项目环境变量中将 <code>MEDIA_CONNECTIONS_ENABLED</code> 设为 <code>false</code> 并重新部署。', '<strong>Connections are enabled.</strong> To pause public room access, set <code>MEDIA_CONNECTIONS_ENABLED</code> to <code>false</code> in Vercel and redeploy.'],
      ['<strong>连接服务已暂停。</strong> 房间创建、加入、续期和心跳请求都会返回 503。恢复时将 Vercel 环境变量 <code>MEDIA_CONNECTIONS_ENABLED</code> 设为 <code>true</code> 并重新部署。', '<strong>Connections are paused.</strong> Room creation, joining, credential refresh, and heartbeat requests return 503. To resume, set <code>MEDIA_CONNECTIONS_ENABLED</code> to <code>true</code> in Vercel and redeploy.'],
      ['尚未配置 Amazon IVS Chat。请通过 IVS_CHAT_REGION、AWS_REGION、AWS_DEFAULT_REGION 或当前 AWS profile 设置区域，并通过服务器 IAM 凭证链提供 AWS 凭证。', 'Amazon IVS Chat is not configured. Set an AWS region through IVS_CHAT_REGION, AWS_REGION, AWS_DEFAULT_REGION, or the active AWS profile, and provide AWS credentials through the server IAM credential chain.'],
      ['实时记录房间创建、成员进出、通道切换与强制关闭操作', 'Live audit trail of room creation, participant joins/leaves, provider routing, and closures'],
      ['系统核心指标', 'System telemetry metrics'],
      ['双轴通道调度中枢', 'Dual-axis provider routing control'],
      ['会话与系统日志工作区', 'Sessions and audit log workspace'],
    ];
    translationPairs.push(['概览', 'Overview'], ['房间', 'Rooms'], ['服务', 'Services'], ['事件', 'Events'], ['管理导航', 'Console navigation'], ['管理密码', 'Admin password']);
    const zhToEn = new Map(translationPairs);
    const enToZh = new Map(translationPairs.map(([zh, en]) => [en, zh]));
export let currentLanguage = (() => {
      try {
        const saved = localStorage.getItem('demo-dashboard-language');
        if (saved === 'zh' || saved === 'en') return saved;
      } catch (_) { console.debug('Dashboard preference storage is unavailable'); }
      return navigator.language?.toLowerCase().startsWith('zh') ? 'zh' : 'en';
    })();

    export function t(value, values = {}) {
      const source = String(value ?? '');
      let result = currentLanguage === 'en'
        ? (zhToEn.get(source) || source)
        : (enToZh.get(source) || source);
      for (const [key, replacement] of Object.entries(values)) {
        result = result.replaceAll(`{${key}}`, String(replacement));
      }
      return result;
    }

    export function applyLanguage(root = document.body) {
      document.documentElement.lang = currentLanguage === 'zh' ? 'zh-CN' : 'en';
      document.title = t('Media Live Console · 智能直播控制台');
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      let node;
      while ((node = walker.nextNode())) {
        if (node.parentElement?.closest('script, style')) continue;
        const raw = node.nodeValue || '';
        const trimmed = raw.trim();
        if (!trimmed) continue;
        const translated = t(trimmed);
        if (translated !== trimmed) node.nodeValue = raw.replace(trimmed, translated);
      }
      for (const attribute of ['placeholder', 'title', 'aria-label']) {
        root.querySelectorAll(`[${attribute}]`).forEach((element) => {
          const value = element.getAttribute(attribute);
          if (value) element.setAttribute(attribute, t(value));
        });
      }
      const selector = document.getElementById('language-select');
      if (selector) selector.value = currentLanguage;
    }

    export function setLanguage(language) {
      currentLanguage = language === 'zh' ? 'zh' : 'en';
      try { localStorage.setItem('demo-dashboard-language', currentLanguage); } catch (_) { console.debug('Dashboard preference storage is unavailable'); }
      applyLanguage();
      document.dispatchEvent(new Event('dashboard:language'));
    }
