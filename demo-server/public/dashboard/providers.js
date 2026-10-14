import { t, currentLanguage } from './i18n.js';
import { store } from './state.js';
import { api } from './api.js';
import { toast } from './feedback.js';
import { requestRefresh } from './refresh-signal.js';
import { esc, formatTime } from './format.js';

export async function switchProvider(provider) {
      try {
        const d = await api('/api/provider', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ provider })
        });
        await requestRefresh();
        const label = providerLabel(d.activeProvider);
        toast(t('新房间媒体通道已切换为 <b>{label}</b>', { label }), 'success');
      } catch (e) {
        toast(t('Provider 切换失败: {message}', { message: e.message }), 'error');
      }
    }

    export async function switchChatProvider(provider) {
      try {
        const d = await api('/api/chat-provider', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ provider })
        });
        await requestRefresh();
        const label = chatProviderLabel(d.activeChatProvider);
        toast(
          d.activeChatProvider
            ? t('新房间聊天服务已切换为 <b>{label}</b>', { label })
            : t('新房间产品聊天已关闭'),
          'success'
        );
      } catch (e) {
        toast(t('Chat Provider 切换失败: {message}', { message: e.message }), 'error');
      }
    }

    export function providerInfo(provider) {
      return store.providers.get(provider) || {
        id: provider,
        displayName: provider,
        label: provider,
        description: '',
        configured: true,
      };
    }

    export function providerLabel(provider) {
      const info = providerInfo(provider);
      return t(info.label || info.displayName || provider);
    }

    export function chatProviderInfo(provider) {
      if (!provider) {
        return {
          id: 'none',
          displayName: 'Disabled',
          label: '关闭 Chat',
          description: '不为新房间创建产品聊天服务',
          configured: true,
        };
      }
      return store.chatProviders.get(provider) || {
        id: provider,
        displayName: provider,
        label: provider,
        description: '',
        configured: true,
      };
    }

    export function chatProviderLabel(provider) {
      const info = chatProviderInfo(provider);
      return t(info.label || info.displayName || provider || '关闭 Chat');
    }

    export function providerHue(provider) {
      let hash = 0;
      for (const char of String(provider || 'provider')) {
        hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
      }
      return hash % 360;
    }

    export function capabilityStateLabel(support) {
      switch (support) {
        case 'supported':
          return t('支持');
        case 'conditional':
          return t('有条件');
        default:
          return t('不支持');
      }
    }

    let hoveredCapabilityHelp = null;
    let focusedCapabilityHelp = null;
    let activeCapabilityTooltipTarget = null;
    let capabilityTooltipElement = null;

    export function getCapabilityTooltipElement() {
      if (capabilityTooltipElement) return capabilityTooltipElement;
      capabilityTooltipElement = document.createElement('div');
      capabilityTooltipElement.id = 'capability-help-tooltip';
      capabilityTooltipElement.className = 'capability-tooltip';
      capabilityTooltipElement.setAttribute('role', 'tooltip');
      capabilityTooltipElement.hidden = true;
      document.body.appendChild(capabilityTooltipElement);
      return capabilityTooltipElement;
    }

    export function updateCapabilityTooltip() {
      if (hoveredCapabilityHelp && !hoveredCapabilityHelp.isConnected) {
        hoveredCapabilityHelp = null;
      }
      if (focusedCapabilityHelp && !focusedCapabilityHelp.isConnected) {
        focusedCapabilityHelp = null;
      }
      const button = focusedCapabilityHelp || hoveredCapabilityHelp;
      const tooltip = getCapabilityTooltipElement();
      if (!button || !button.isConnected || !button.dataset.note) {
        if (activeCapabilityTooltipTarget) {
          activeCapabilityTooltipTarget.removeAttribute('aria-describedby');
        }
        activeCapabilityTooltipTarget = null;
        tooltip.hidden = true;
        return;
      }

      if (activeCapabilityTooltipTarget !== button) {
        if (activeCapabilityTooltipTarget) {
          activeCapabilityTooltipTarget.removeAttribute('aria-describedby');
        }
        button.setAttribute('aria-describedby', tooltip.id);
        activeCapabilityTooltipTarget = button;
      }

      tooltip.textContent = button.dataset.note;
      tooltip.hidden = false;
      const buttonRect = button.getBoundingClientRect();
      const tooltipRect = tooltip.getBoundingClientRect();
      const margin = 12;
      let left = buttonRect.left + (buttonRect.width - tooltipRect.width) / 2;
      left = Math.max(margin, Math.min(left, window.innerWidth - tooltipRect.width - margin));
      let top = buttonRect.bottom + 8;
      if (top + tooltipRect.height > window.innerHeight - margin) {
        top = buttonRect.top - tooltipRect.height - 8;
      }
      top = Math.max(margin, Math.min(top, window.innerHeight - tooltipRect.height - margin));
      tooltip.style.left = left + 'px';
      tooltip.style.top = top + 'px';
    }

    document.addEventListener('pointerover', event => {
      const button = event.target.closest?.('.capability-help');
      if (button) {
        hoveredCapabilityHelp = button;
        updateCapabilityTooltip();
      }
    });

    document.addEventListener('pointerout', event => {
      const button = event.target.closest?.('.capability-help');
      if (button && button === hoveredCapabilityHelp && !button.contains(event.relatedTarget)) {
        hoveredCapabilityHelp = null;
        updateCapabilityTooltip();
      }
    });

    document.addEventListener('focusin', event => {
      const button = event.target.closest?.('.capability-help');
      if (button) {
        focusedCapabilityHelp = button;
        updateCapabilityTooltip();
      }
    });

    document.addEventListener('focusout', event => {
      const button = event.target.closest?.('.capability-help');
      if (button && button === focusedCapabilityHelp && !button.contains(event.relatedTarget)) {
        focusedCapabilityHelp = null;
        updateCapabilityTooltip();
      }
    });

    window.addEventListener('resize', updateCapabilityTooltip);
    window.addEventListener('scroll', updateCapabilityTooltip, true);

    export function renderCapabilityMatrix(rootId, providers, activeProvider, emptyText) {
      const root = document.getElementById(rootId);
      if (!root || providers.length === 0) return;

      const rows = new Map();
      for (const provider of providers) {
        for (const capability of provider.capabilities || []) {
          if (!capability || !capability.key || rows.has(capability.key)) continue;
          rows.set(capability.key, {
            key: capability.key,
            label: t(capability.label || capability.key),
          });
        }
      }

      if (rows.size === 0) {
        root.innerHTML = '<div class="empty-state" style="padding:18px;">' + esc(t(emptyText)) + '</div>';
        return;
      }

      const capabilityMaps = new Map(
        providers.map(provider => [
          provider.id,
          new Map((provider.capabilities || []).map(item => [item.key, item])),
        ]),
      );

      let html =
        '<div class="capability-matrix" style="--provider-count:' +
        providers.length +
        '">';
      html += '<div class="capability-cell capability-provider capability-label">' + esc(t('能力')) + '</div>';

      for (const provider of providers) {
        const active = provider.id === activeProvider;
        const classes = [
          'capability-cell',
          'capability-provider',
          active ? 'active-provider' : '',
          provider.configured ? '' : 'unconfigured',
        ].filter(Boolean).join(' ');
        const status = !provider.configured
          ? t('未配置')
          : (active ? t('当前使用') : t('可选择'));
        const providerHelp = !provider.configured && provider.configurationError
          ? (() => {
              const note = t(provider.configurationError);
              const providerName = provider.displayName || provider.id;
              return '<span class="capability-help conditional" role="img" tabindex="0" aria-label="' +
                esc(t('查看 {provider} 的配置要求', { provider: providerName }) + '：' + note) +
                '" data-note="' + esc(note) + '">?</span>';
            })()
          : '';
        const providerDescription = t(provider.description || provider.displayName);
        html +=
          '<div class="' +
          classes +
          '"><span><span title="' +
          esc(providerDescription) +
          '">' +
          esc(t(provider.label || provider.displayName || provider.id)) +
          '</span>' +
          providerHelp +
          '</span><small>' +
          esc(status) +
          '</small></div>';
      }

      for (const row of rows.values()) {
        html +=
          '<div class="capability-cell capability-label">' +
          esc(t(row.label)) +
          '</div>';
        for (const provider of providers) {
          const capability = capabilityMaps.get(provider.id)?.get(row.key);
          const support = capability?.support || 'unsupported';
          const active = provider.id === activeProvider;
          const classes = [
            'capability-cell',
            active ? 'active-provider' : '',
            provider.configured ? '' : 'unconfigured',
          ].filter(Boolean).join(' ');
          const note = t(capability?.note || '');
          const help =
            note
              ? '<span class="capability-help ' +
                esc(support) +
                '" role="img" tabindex="0" aria-label="' +
                esc(t('查看 {provider} {capability} 的能力说明', {
                  provider: provider.displayName || provider.id,
                  capability: row.label,
                }) + '：' + note) +
                '" data-note="' + esc(note) + '">?</span>'
              : '';
          html +=
            '<div class="' +
            classes +
            '"><span class="capability-value"><span class="capability-state ' +
            esc(support) +
            '">' +
            capabilityStateLabel(support) +
            '</span>' +
            help +
            '</span></div>';
        }
      }

      html += '</div>';
      root.innerHTML = html;
      updateCapabilityTooltip();
    }

    export function renderProviderCapabilityMatrix(activeProvider) {
      renderCapabilityMatrix(
        'provider-capability-matrix',
        [...store.providers.values()],
        activeProvider,
        '暂无 Media Provider 能力元数据',
      );
    }

    export function renderChatProviderCapabilityMatrix(activeProvider) {
      renderCapabilityMatrix(
        'chat-provider-capability-matrix',
        [...store.chatProviders.values()],
        activeProvider,
        '暂无 Chat Provider 能力元数据',
      );
    }

    export function renderProviderSwitcher(activeProvider) {
      const switcher = document.getElementById('provider-switcher');
      const providers = [...store.providers.values()];
      switcher.innerHTML = providers.map(provider => {
        const active = provider.id === activeProvider;
        const accent = '#1d1d1f';
        const title = !provider.configured
          ? t(provider.configurationError || '{provider} 尚未完成服务端配置', { provider: provider.displayName })
          : (!store.providerSelectionEnabled && !active
            ? t('线上 Provider 由 MEDIA_DEFAULT_PROVIDER 环境变量配置')
            : t('新房间使用 {provider}', { provider: provider.displayName }));
        return `<button class="provider-opt${active ? ' active' : ''}"
          data-provider="${esc(provider.id)}"
          onclick="switchProvider(this.dataset.provider)"
          style="--provider-accent:${accent}"
          title="${esc(title)}"
          ${provider.configured && (store.providerSelectionEnabled || active) ? '' : 'disabled'}>
          <span class="opt-dot" style="background:${accent}"></span>
          ${esc(t(provider.label || provider.displayName || provider.id))}
        </button>`;
      }).join('');
      renderProviderCapabilityMatrix(activeProvider);
    }

    export function renderChatProviderSwitcher(activeProvider) {
      const switcher = document.getElementById('chat-provider-switcher');
      const providers = [
        {
          id: 'none',
          displayName: 'Disabled',
          label: '关闭 Chat',
          description: '不为新房间创建产品聊天服务',
          configured: true,
        },
        ...store.chatProviders.values(),
      ];
      switcher.innerHTML = providers.map(provider => {
        const providerId = provider.id === 'none' ? null : provider.id;
        const active = providerId === activeProvider;
        const accent = provider.id === 'none'
          ? '#94a3b8'
          : '#1d1d1f';
        const title = !provider.configured
          ? t(provider.configurationError || '{provider} 尚未完成服务端配置', { provider: provider.displayName })
          : (providerId
            ? t('新房间使用 {provider}', { provider: provider.displayName })
            : t('新房间不创建产品聊天服务'));
        return `<button class="provider-opt${active ? ' active' : ''}"
          data-provider="${esc(provider.id)}"
          onclick="switchChatProvider(this.dataset.provider)"
          style="--provider-accent:${accent}"
          title="${esc(title)}"
          ${provider.configured ? '' : 'disabled'}>
          <span class="opt-dot" style="background:${accent}"></span>
          ${esc(t(provider.label || provider.displayName || provider.id))}
        </button>`;
      }).join('');
      renderChatProviderCapabilityMatrix(activeProvider);
    }
