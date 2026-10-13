import { currentLanguage } from './i18n.js';
export function esc(s) {
      return String(s ?? '').replace(/[&<>"]/g, c => ({
        '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'
      }[c]));
    }

    export function formatTime(isoStr) {
      if (!isoStr) return '—';
      try {
        const d = new Date(isoStr);
        const locale = currentLanguage === 'zh' ? 'zh-CN' : 'en-US';
        return d.toLocaleTimeString(locale, { hour12: false }) + ' (' + d.toLocaleDateString(locale, { month: '2-digit', day: '2-digit' }) + ')';
      } catch {
        return esc(isoStr);
      }
    }
