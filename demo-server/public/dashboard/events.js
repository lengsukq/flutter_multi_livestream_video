import { t, currentLanguage } from './i18n.js';
import { store } from './state.js';
import { esc, formatTime } from './format.js';

export function eventTagClass(type) {
      switch (type) {
        case 'room-create':
        case 'create':
          return 'tag-room-create';
        case 'attendee-join':
        case 'join':
          return 'tag-attendee-join';
        case 'leave':
          return 'tag-leave';
        case 'delete':
        case 'room-close':
        case 'room-close-force':
          return 'tag-delete';
        default:
          return 'tag-default';
      }
    }

    export function setEventFilter(category, btn) {
      store.eventFilter = category;
      document.querySelectorAll('.filter-tab').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      renderEvents();
    }

    export function renderEvents() {
      const ev = document.getElementById('events');
      const badge = document.getElementById('event-badge-count');
      if (badge) badge.textContent = (store.events || []).length;
      let filtered = store.events;
      if (store.eventFilter !== 'all') {
        filtered = store.events.filter(e => {
          const type = (e.type || '').toLowerCase();
          return type.includes(store.eventFilter);
        });
      }

      if (filtered && filtered.length) {
        ev.innerHTML = filtered.map(e => `
          <div class="event-line">
            <span class="event-ts">${formatTime(e.ts)}</span>
            <span class="event-tag ${eventTagClass(e.type)}">${esc(e.type)}</span>
            <span class="event-msg">${esc(e.message)}</span>
          </div>
        `).join('');
      } else {
        ev.innerHTML = '<div class="event-line"><span class="event-msg" style="color: #94a3b8;">' + esc(t('暂无对应事件流记录')) + '</span></div>';
      }
    }
