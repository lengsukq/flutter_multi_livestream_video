import { api } from './api.js';
import { toast } from './feedback.js';
import { requestRefresh } from './refresh-signal.js';
import { t } from './i18n.js';
let timer = null;
    export function showLogin(message = '') {
      if (timer) clearInterval(timer);
      timer = null;
      document.getElementById('dashboard-root').classList.add('auth-hidden');
      document.getElementById('admin-login').classList.remove('hidden');
      document.getElementById('login-error').textContent = message;
      document.getElementById('admin-password').focus();
    }

    export function showDashboard() {
      document.getElementById('admin-login').classList.add('hidden');
      document.getElementById('dashboard-root').classList.remove('auth-hidden');
      document.getElementById('login-error').textContent = '';
    }

    export async function login(event) {
      event.preventDefault();
      const button = document.getElementById('login-button');
      const password = document.getElementById('admin-password').value;
      button.disabled = true;
      document.getElementById('login-error').textContent = '';
      try {
        await api('/api/admin/login', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ password }),
        });
        document.getElementById('admin-password').value = '';
        showDashboard();
        await requestRefresh();
        timer = setInterval(requestRefresh, 5000);
      } catch (error) {
        document.getElementById('login-error').textContent = error.message;
      } finally {
        button.disabled = false;
      }
    }

    export async function logout() {
      try { await api('/api/admin/logout', { method: 'POST' }); } catch (_) { }
      showLogin(t('已退出登录'));
    }

    export async function initialize() {
      try {
        await api('/api/admin/session');
        showDashboard();
        await requestRefresh();
        timer = setInterval(requestRefresh, 5000);
      } catch (error) {
        showLogin(error.status === 503
          ? t('管理登录尚未配置，请在服务端设置 MEDIA_ADMIN_PASSWORD。')
          : t('请输入管理密码登录。'));
      }
    }
