import { t, currentLanguage } from './i18n.js';
import { store } from './state.js';
import { api } from './api.js';
import { toast } from './feedback.js';
import { requestRefresh } from './refresh-signal.js';
import { esc, formatTime } from './format.js';
import { providerInfo, providerLabel, chatProviderInfo, chatProviderLabel, providerHue } from './providers.js';

export function generateRandomCode() {
      const code = String(Math.floor(100000 + Math.random() * 900000));
      document.getElementById('new-code').value = code;
    }

    export function renderRoomsTable() {
      const query = (document.getElementById('room-search')?.value || '').trim().toLowerCase();
      const tb = document.getElementById('rooms');

      let list = store.rooms;
      if (query) {
        list = list.filter(r => {
          if (r.roomCode && r.roomCode.toLowerCase().includes(query)) return true;
          if (r.provider && r.provider.toLowerCase().includes(query)) return true;
          if (r.chatProvider && r.chatProvider.toLowerCase().includes(query)) return true;
          if (r.attendees && r.attendees.some(a => (a.externalUserId || '').toLowerCase().includes(query))) return true;
          return false;
        });
      }

      if (!list || !list.length) {
        tb.innerHTML = `<tr><td colspan="7">
          <div class="empty-state">
            <svg fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24"><path d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/></svg>
            <p>${query ? t('没有找到符合条件的房间') : t('当前暂无活跃房间，可通过上方快速创建')}</p>
          </div>
        </td></tr>`;
        return;
      }

      tb.innerHTML = list.map(r => {
        const provider = providerInfo(r.provider);
        const roomProviderLabel = t(provider.displayName || provider.label || r.provider);
        const roomChatProvider = chatProviderInfo(r.chatProvider);
        const roomChatProviderLabel = r.chatProvider
          ? t(roomChatProvider.displayName || roomChatProvider.label || r.chatProvider)
          : t('Chat 已关闭');
        const hue = providerHue(r.provider);
        const providerStyle = `background:hsl(${hue} 80% 97%);color:hsl(${hue} 58% 38%);border-color:hsl(${hue} 65% 86%)`;
        const chatHue = r.chatProvider ? providerHue(r.chatProvider) : 215;
        const chatProviderStyle = `background:hsl(${chatHue} 55% 97%);color:hsl(${chatHue} 42% 42%);border-color:hsl(${chatHue} 45% 88%)`;
        const idleText = r.idleSec > 0
          ? t('{seconds}s 前心跳', { seconds: r.idleSec })
          : t('🟢 活跃在线');
        const attendeesHtml = r.attendees && r.attendees.length
          ? `<div class="attendee-chips">` + r.attendees.map(a => {
              const name = a.externalUserId || 'Guest';
              const initial = name.charAt(0).toUpperCase();
              const deviceHint = a.deviceId
                ? t(' · 设备: {device}', { device: esc(a.deviceId.slice(0, 8)) + '…' })
                : '';
              return `
                <span class="user-chip" title="${esc(t('加入时间: {time}{role}', { time: a.joinedAt, role: deviceHint }))}">
                  <span class="user-chip-avatar">${esc(initial)}</span>
                  ${esc(name)}
                </span>
              `;
            }).join('') + `</div>`
          : `<span style="color: var(--text-tertiary); font-size: 13px;">${t('无在线成员')}</span>`;

        return `<tr>
          <td>
            <div class="room-code-tag">${esc(r.roomCode)}</div>
            <div class="meeting-id-sub">${esc((r.meetingId || '').slice(0, 18))}${(r.meetingId || '').length > 18 ? '…' : ''}</div>
          </td>
          <td>
            <span class="provider-pill" style="${providerStyle}">
              ${esc(roomProviderLabel)}
            </span>
            <div style="margin-top:6px">
              <span class="provider-pill" style="${chatProviderStyle}">
                Chat · ${esc(roomChatProviderLabel)}
              </span>
            </div>
          </td>
          <td>
            <span style="font-weight: 700; font-size: 15px; color: ${r.attendeeCount > 0 ? 'var(--emerald-color)' : 'var(--text-tertiary)'}">
              ${r.attendeeCount}
            </span>
          </td>
          <td>${attendeesHtml}</td>
          <td>
            <span style="font-size: 13px; color: ${r.idleSec > 60 ? 'var(--amber-color)' : 'var(--text-muted)'};">
              ${idleText}
            </span>
          </td>
          <td style="font-size: 13px; color: var(--text-tertiary);">
            ${formatTime(r.createdAt)}
          </td>
          <td>
            <div class="action-cell">
              <button class="btn btn-subtle btn-sm" onclick="copyRoom('${esc(r.roomCode)}')">
                <svg width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/></svg>
                ${t('复制房号')}
              </button>
              ${r.shareLink ? `
              <button class="btn btn-subtle btn-sm" onclick="copyLink('${esc(r.shareLink)}')">
                <svg width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71"/></svg>
                ${t('分享链接')}
              </button>` : ''}
              <button class="btn btn-danger-subtle" onclick="promptCloseRoom('${esc(r.roomCode)}')">
                ${t('关闭')}
              </button>
            </div>
          </td>
        </tr>`;
      }).join('');
    }

    export function renderStandaloneChatRoomsTable() {
      const tb = document.getElementById('standalone-chat-rooms');
      const list = store.chatRooms || [];
      document.getElementById('standalone-chat-room-badge-count').textContent = list.length;

      if (!list.length) {
        tb.innerHTML = `<tr><td colspan="6" class="standalone-chat-table-empty-cell">
          <div class="standalone-chat-empty">
            <div class="standalone-chat-empty-icon" aria-hidden="true">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <path d="M21 15a4 4 0 01-4 4H7l-4 3V7a4 4 0 014-4h10a4 4 0 014 4z"></path>
              </svg>
            </div>
            <div class="standalone-chat-empty-title">${t('当前暂无云端聊天室')}</div>
            <div class="standalone-chat-empty-desc">${t('可在 Flutter Demo 的“独立聊天”入口创建。')}</div>
          </div>
        </td></tr>`;
        return;
      }

      tb.innerHTML = list.map(r => {
        const provider = chatProviderInfo(r.chatProvider);
        const providerLabel = t(provider.displayName || provider.label || r.chatProvider || 'Unknown');
        const hue = providerHue(r.chatProvider || 'chat');
        const providerStyle = `background:hsl(${hue} 55% 97%);color:hsl(${hue} 42% 42%);border-color:hsl(${hue} 45% 88%)`;
        const remoteId = r.providerRoomId || '';
        const displayCode = r.roomCode || '—';
        const trackedLabel = r.tracked ? t('本地已关联') : t('云端遗留');
        const trackedStyle = r.tracked
          ? 'background:var(--emerald-bg);color:var(--emerald-color);border-color:var(--emerald-border)'
          : 'background:#fff7ed;color:#c2410c;border-color:#fed7aa';

        return `<tr>
          <td>
            <div class="room-code-tag">${esc(displayCode)}</div>
            <div class="meeting-id-sub" title="${esc(remoteId)}">${esc(remoteId)}</div>
          </td>
          <td>
            <span class="provider-pill" style="${providerStyle}">
              ${esc(providerLabel)}
            </span>
          </td>
          <td>
            <span style="font-weight: 700; font-size: 15px; color: ${(r.memberCount || 0) > 0 ? 'var(--emerald-color)' : 'var(--text-tertiary)'}">
              ${r.memberCount || 0}
            </span>
          </td>
          <td>
            <span class="provider-pill" style="${trackedStyle}">
              ${esc(trackedLabel)}
            </span>
          </td>
          <td style="font-size: 13px; color: var(--text-tertiary);">
            ${r.createdAt ? formatTime(r.createdAt) : '—'}
          </td>
          <td>
            <div class="action-cell">
              ${r.roomCode ? `
                <button class="btn btn-subtle btn-sm" onclick="copyRoom('${esc(r.roomCode)}')">
                  ${t('复制房号')}
                </button>
              ` : `
                <button class="btn btn-subtle btn-sm" onclick="copyRoom('${esc(remoteId)}')">
                  ${t('复制云端群 ID')}
                </button>
              `}
              <button
                class="btn btn-danger-subtle"
                data-provider="${esc(r.chatProvider || '')}"
                data-room-id="${esc(remoteId)}"
                data-room-code="${esc(r.roomCode || '')}"
                data-tracked="${r.tracked ? 'true' : 'false'}"
                onclick="promptCloseChatRoom(this)">
                ${t('关闭')}
              </button>
            </div>
          </td>
        </tr>`;
      }).join('');
    }

    export async function createRoom() {
      const input = document.getElementById('new-code');
      const code = input.value.trim();
      try {
        const d = await api('/rooms', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(code ? { roomCode: code } : {})
        });
        input.value = '';
        await requestRefresh();
        toast(t('✨ 房间 <b>{code}</b> 已成功创建', { code: d.roomCode }), 'success');
      } catch (e) {
        toast(t('创建房间失败: {message}', { message: e.message }), 'error');
      }
    }

    let targetCloseRoomCode = null;
    let targetCloseChatRoom = null;

    export function promptCloseRoom(code) {
      targetCloseRoomCode = code;
      document.getElementById('modal-title').textContent = t('强制关闭房间 {code}？', { code });
      document.getElementById('modal-desc').textContent = t('确认关闭房间 {code}？此操作将立即断开所有在线成员的音视频连接并清理云端会话。', { code });
      document.getElementById('modal-confirm-btn').onclick = executeCloseRoom;
      document.getElementById('confirm-modal').classList.add('open');
    }

    export function promptCloseChatRoom(button) {
      const provider = button.dataset.provider || '';
      const providerRoomId = button.dataset.roomId || '';
      const roomCode = button.dataset.roomCode || '';
      const tracked = button.dataset.tracked === 'true';
      targetCloseChatRoom = { provider, providerRoomId, roomCode, tracked };
      const label = roomCode || providerRoomId;
      document.getElementById('modal-title').textContent = t('关闭独立聊天室 {code}？', { code: label });
      document.getElementById('modal-desc').textContent = t('确认关闭独立聊天室 {code}？此操作会清理对应 Chat Provider 的云端聊天室，并让现有客户端失去该聊天室连接。', { code: label });
      document.getElementById('modal-confirm-btn').onclick = executeCloseChatRoom;
      document.getElementById('confirm-modal').classList.add('open');
    }

    export function closeConfirmModal() {
      document.getElementById('confirm-modal').classList.remove('open');
      targetCloseRoomCode = null;
    }

    export async function executeCloseRoom() {
      if (!targetCloseRoomCode) return;
      const code = targetCloseRoomCode;
      closeConfirmModal();
      try {
        await api('/rooms/' + encodeURIComponent(code), { method: 'DELETE' });
        await requestRefresh();
        toast(t('房间 {code} 已强制关闭', { code }), 'success');
      } catch (e) {
        toast(t('关闭房间失败: {message}', { message: e.message }), 'error');
      }
    }

    export async function executeCloseChatRoom() {
      if (!targetCloseChatRoom) return;
      const target = targetCloseChatRoom;
      targetCloseChatRoom = null;
      closeConfirmModal();
      try {
        const url = target.tracked && target.roomCode
          ? '/api/chat/rooms/' + encodeURIComponent(target.roomCode)
          : '/api/chat/cloud-rooms/' +
              encodeURIComponent(target.provider) +
              '/' +
              encodeURIComponent(target.providerRoomId);
        await api(url, { method: 'DELETE' });
        await requestRefresh();
        toast(
          t('云端聊天室 {code} 已删除', {
            code: target.roomCode || target.providerRoomId,
          }),
          'success',
        );
      } catch (e) {
        toast(t('删除云端聊天室失败: {message}', { message: e.message }), 'error');
      }
    }

    export function copyRoom(code) {
      navigator.clipboard.writeText(code).then(() => {
        toast(t('已复制房间号 <b>{code}</b> 到剪贴板', { code }), 'success');
      }).catch(() => {
        toast(t('房间号: {code}', { code }));
      });
    }

    export function copyLink(link) {
      navigator.clipboard.writeText(link).then(() => {
        toast(t('已复制入会深度链接到剪贴板'), 'success');
      }).catch(() => {
        toast(t('链接: {link}', { link }));
      });
    }
