
export function toast(text, type = 'info') {
      const c = document.getElementById('toast-container');
      const t = document.createElement('div');
      t.className = `toast ${type}`;
      t.innerHTML = text;
      c.appendChild(t);
      setTimeout(() => t.classList.add('show'), 10);
      setTimeout(() => {
        t.classList.remove('show');
        setTimeout(() => t.remove(), 350);
      }, 3500);
    }
