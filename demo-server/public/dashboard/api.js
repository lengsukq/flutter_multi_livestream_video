import { t, currentLanguage } from './i18n.js';
export async function api(path, opts = {}) {
      const headers = new Headers(opts.headers || {});
      headers.set('Accept-Language', currentLanguage === 'zh' ? 'zh-CN' : 'en');
      const r = await fetch(path, { ...opts, headers });
      const d = await r.json().catch(() => ({}));
      if (!r.ok) {
        const error = new Error(d.error?.message || d.message || t('HTTP {status}', { status: r.status }));
        error.status = r.status;
        throw error;
      }
      return d;
    }
