/* ============================================
   QRBAS — SPA Router + API Helpers
   ============================================ */

const API = {
  async get(path) {
    const res = await fetch(path);
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(err.error || res.status + '');
    }
    return res.json();
  },
  async post(path, body) {
    const res = await fetch(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(err.error || res.status + '');
    }
    return res.json();
  },
  async put(path, body) {
    const res = await fetch(path, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body)
    });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(err.error || res.status + '');
    }
    return res.json();
  },
  async del(path) {
    const res = await fetch(path, { method: 'DELETE' });
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: res.statusText }));
      throw new Error(err.error || res.status + '');
    }
    return res.json();
  }
};

// --- Toast notifications ---

function showToast(message, type) {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.className = 'toast' + (type ? ' toast-' + type : '');
  toast.textContent = message;
  document.body.appendChild(toast);

  setTimeout(() => toast.remove(), 3000);
}

// --- Router ---

function navigate(hash) {
  window.location.hash = hash;
}

function getRoute() {
  const hash = window.location.hash || '#/scanner';
  const parts = hash.slice(2).split('/'); // remove #/
  return { path: parts[0] || 'scanner', params: parts.slice(1) };
}

function render() {
  const route = getRoute();
  const app = document.getElementById('app');

  // Update active tab
  document.querySelectorAll('.tab-item').forEach(el => {
    el.classList.toggle('active', el.dataset.tab === route.path);
  });

  // Hide tab nav on equipment view (fullscreen feel)
  const nav = document.getElementById('tab-nav');
  nav.style.display = route.path === 'equipment' ? 'none' : '';

  switch (route.path) {
    case 'scanner':
      renderScanner(app);
      break;
    case 'equipment':
      renderEquipment(app, route.params[0]);
      break;
    case 'admin':
      renderAdmin(app, route.params);
      break;
    default:
      renderScanner(app);
  }
}

window.addEventListener('hashchange', render);
window.addEventListener('DOMContentLoaded', () => {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js');
  }
  render();
  setupInstallBanner();
});

// --- PWA install banner ---

let deferredInstallPrompt = null;

window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredInstallPrompt = e;
});

function isStandalone() {
  return window.matchMedia('(display-mode: standalone)').matches ||
    window.navigator.standalone === true;
}

function isIOS() {
  return /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
}

function setupInstallBanner() {
  if (isStandalone()) return;
  if (localStorage.getItem('pwa-dismissed')) return;

  // Only show on equipment view — that's where techs live.
  if (getRoute().path !== 'equipment') {
    window.addEventListener('hashchange', setupInstallBanner, { once: true });
    return;
  }

  // Wait one beat so the equipment renderer has written its markup.
  setTimeout(showInstallBanner, 1200);
}

function showInstallBanner() {
  if (document.getElementById('pwa-banner')) return;
  if (isStandalone()) return;

  const banner = document.createElement('div');
  banner.id = 'pwa-banner';
  banner.className = 'pwa-banner';

  const hint = isIOS()
    ? 'Tap Share → Add to Home Screen for faster access next scan.'
    : deferredInstallPrompt
      ? 'Install this app for faster access on future scans.'
      : 'Add this page to your home screen for faster scans.';

  banner.innerHTML =
    '<div class="pwa-banner-text">' + hint + '</div>' +
    '<div class="pwa-banner-actions">' +
      (deferredInstallPrompt ? '<button id="pwa-install" class="btn btn-sm btn-primary">Install</button>' : '') +
      '<button id="pwa-dismiss" class="btn btn-sm">Dismiss</button>' +
    '</div>';

  document.body.appendChild(banner);

  const installBtn = document.getElementById('pwa-install');
  if (installBtn) {
    installBtn.addEventListener('click', () => {
      if (!deferredInstallPrompt) return;
      deferredInstallPrompt.prompt();
      deferredInstallPrompt.userChoice.finally(() => {
        deferredInstallPrompt = null;
        banner.remove();
        localStorage.setItem('pwa-dismissed', '1');
      });
    });
  }
  document.getElementById('pwa-dismiss').addEventListener('click', () => {
    banner.remove();
    localStorage.setItem('pwa-dismissed', '1');
  });
}

// --- Stubs (replaced by scanner.js, equipment.js, admin.js) ---

if (typeof renderScanner === 'undefined') {
  window.renderScanner = (el) => {
    el.innerHTML = '<div class="container"><div class="loading"><div class="spinner"></div><span>Scanner loading...</span></div></div>';
  };
}
if (typeof renderEquipment === 'undefined') {
  window.renderEquipment = (el) => {
    el.innerHTML = '<div class="container"><div class="loading"><div class="spinner"></div></div></div>';
  };
}
if (typeof renderAdmin === 'undefined') {
  window.renderAdmin = (el) => {
    el.innerHTML = '<div class="container"><div class="loading"><div class="spinner"></div></div></div>';
  };
}
