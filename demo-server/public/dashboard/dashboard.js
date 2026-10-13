import { t, currentLanguage } from './i18n.js';
import { store } from './state.js';
import { api } from './api.js';
import { toast } from './feedback.js';
import { requestRefresh } from './refresh-signal.js';
import { esc, formatTime } from './format.js';
import { applyLanguage, setLanguage } from './i18n.js';
import { switchProvider, switchChatProvider, providerInfo, providerLabel, chatProviderInfo, chatProviderLabel, providerHue, capabilityStateLabel, getCapabilityTooltipElement, updateCapabilityTooltip, renderCapabilityMatrix, renderProviderCapabilityMatrix, renderChatProviderCapabilityMatrix, renderProviderSwitcher, renderChatProviderSwitcher } from './providers.js';
import { generateRandomCode, renderRoomsTable, renderStandaloneChatRoomsTable, createRoom, promptCloseRoom, promptCloseChatRoom, closeConfirmModal, executeCloseRoom, executeCloseChatRoom, copyRoom, copyLink } from './rooms.js';
import { eventTagClass, setEventFilter, renderEvents } from './events.js';
import { showLogin, showDashboard, login, logout, initialize } from './auth.js';

export function switchWorkspaceTab(tabName) {
      const panels = {
        'rooms': 'workspace-panel-rooms',
        'chat-rooms': 'workspace-panel-chat-rooms',
        'events': 'workspace-panel-events',
      };
      const targetId = panels[tabName] || panels.rooms;
      document.querySelectorAll('[data-workspace-tab]').forEach(btn => {
        const isMatch = btn.dataset.workspaceTab === tabName;
        btn.classList.toggle('active', isMatch);
        btn.setAttribute('aria-selected', isMatch ? 'true' : 'false');
      });
      Object.values(panels).forEach(panelId => {
        const panel = document.getElementById(panelId);
        if (!panel) return;
        const isActive = panelId === targetId;
        panel.classList.toggle('active', isActive);
        panel.hidden = !isActive;
      });
    }

export async function refresh() {
      const refreshBtn = document.getElementById('refresh-btn');
      refreshBtn.style.opacity = '0.6';
      try {
        const d = await api('/api/overview');
        store.providerSelectionEnabled = d.providerSelectionEnabled !== false;
        const providerList = d.providerList || Object.values(d.providers || {});
        const chatProviderList = d.chatProviderList || Object.values(d.chatProviders || {});
        store.providers = new Map(providerList.map(provider => [provider.id, provider]));
        store.chatProviders = new Map(chatProviderList.map(provider => [provider.id, provider]));
        const currentProvider = providerInfo(d.activeProvider);
        const providerName = t(currentProvider.displayName || currentProvider.label || d.activeProvider);
        const currentChatProvider = chatProviderInfo(d.activeChatProvider);
        const chatProviderName = d.activeChatProvider
          ? t(currentChatProvider.displayName || currentChatProvider.label || d.activeChatProvider)
          : t('Chat 已关闭');
        document.getElementById('header-meta').textContent =
          `Media: ${providerName} · Chat: ${chatProviderName}`;
        const status = document.getElementById('service-status');
        const banner = document.getElementById('connection-banner');
        status.classList.toggle('paused', !d.connectionsEnabled);
        status.innerHTML = `<span class="pulse-dot"></span>${d.connectionsEnabled ? t('连接服务开启') : t('连接服务已暂停')}`;
        banner.classList.toggle('enabled', Boolean(d.connectionsEnabled));
        banner.innerHTML = d.connectionsEnabled
          ? t('<strong>连接服务已开启。</strong> 如需暂停公网入会，请在 Vercel 项目环境变量中将 <code>MEDIA_CONNECTIONS_ENABLED</code> 设为 <code>false</code> 并重新部署。')
          : t('<strong>连接服务已暂停。</strong> 房间创建、加入、续期和心跳请求都会返回 503。恢复时将 Vercel 环境变量 <code>MEDIA_CONNECTIONS_ENABLED</code> 设为 <code>true</code> 并重新部署。');
        document.getElementById('provider-panel-note').textContent = store.providerSelectionEnabled
          ? t('控制端动态切换后续新建房间绑定的云厂商底层通道。已创建房间会始终沿用各自创建时的通道，互不干扰。')
          : t('线上默认通道由 Vercel 的 MEDIA_DEFAULT_PROVIDER 环境变量决定；修改后需重新部署。');
        document.getElementById('chat-provider-panel-note').textContent =
          t('聊天与音视频独立选择。切换只影响后续新建房间；关闭 Chat 时不会创建产品聊天服务。Vercel Function 的选择只保存在当前实例，实例重启后会回到 CHAT_DEFAULT_PROVIDER（未设置则关闭），不同实例间也不会同步。');
        document.getElementById('region-tags').textContent =
          `${d.controlRegion} / ${d.mediaRegion}`;
        renderProviderSwitcher(d.activeProvider);
        renderChatProviderSwitcher(d.activeChatProvider || null);

        document.getElementById('c-rooms').textContent = d.roomCount;
        document.getElementById('c-att').textContent = d.attendeeCount;
        document.getElementById('c-provider').textContent = providerName;
        document.getElementById('c-provider-sub').textContent = t(currentProvider.description || 'Realtime media provider');
        document.getElementById('room-badge-count').textContent = d.roomCount;

        const mins = Math.floor(d.uptimeSec / 60);
        const hours = Math.floor(mins / 60);
        document.getElementById('c-up').textContent =
          hours > 0
            ? t('⏱ {hours} 小时 {minutes} 分钟', { hours, minutes: mins % 60 })
            : t('{minutes} 分钟', { minutes: mins });
        document.getElementById('c-started').textContent =
          t('启动于 {time}', { time: formatTime(d.startedAt) });

        store.rooms = d.rooms || [];
        const cloudChat = d.activeChatProvider
          ? await api(
              '/api/chat/cloud-rooms?provider=' +
              encodeURIComponent(d.activeChatProvider),
            )
          : { rooms: [] };
        store.chatRooms = cloudChat.rooms || [];
        document.getElementById('c-standalone-chat-rooms').textContent =
          store.chatRooms.length;
        document.getElementById('c-standalone-chat-attendees').textContent =
          store.chatRooms.reduce(
            (sum, room) => sum + Number(room.memberCount || 0),
            0,
          );
        store.events = d.events || [];

        renderRoomsTable();
        renderStandaloneChatRoomsTable();
        renderEvents();
      } catch (e) {
        if (e.status === 401) return showLogin(t('登录已过期，请重新登录。'));
        toast(t('刷新数据失败: {message}', { message: e.message }), 'error');
      } finally {
        refreshBtn.style.opacity = '1';
      }
    }


    document.addEventListener('dashboard:refresh', (event) => {
      void refresh().finally(() => event.detail());
    });
    document.addEventListener('dashboard:language', () => {
      renderRoomsTable(); renderStandaloneChatRoomsTable(); renderEvents();
      if (!document.getElementById('dashboard-root').classList.contains('auth-hidden')) void refresh();
    });
Object.assign(window, { setLanguage, switchWorkspaceTab, switchProvider, switchChatProvider, providerInfo, providerLabel, chatProviderInfo, chatProviderLabel, providerHue, capabilityStateLabel, getCapabilityTooltipElement, updateCapabilityTooltip, renderCapabilityMatrix, renderProviderCapabilityMatrix, renderChatProviderCapabilityMatrix, renderProviderSwitcher, renderChatProviderSwitcher, generateRandomCode, renderRoomsTable, renderStandaloneChatRoomsTable, createRoom, promptCloseRoom, promptCloseChatRoom, closeConfirmModal, executeCloseRoom, executeCloseChatRoom, copyRoom, copyLink, eventTagClass, setEventFilter, renderEvents, showLogin, showDashboard, login, logout, initialize });
    // Enter key creates room
    document.getElementById('new-code').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') createRoom();
    });

    applyLanguage();
    initialize();
