const CACHE_NAME = 'qrbas-v3';
const SHELL_URLS = [
  '/',
  '/css/style.css',
  '/js/app.js',
  '/js/scanner.js',
  '/js/equipment.js',
  '/js/admin.js',
  '/js/tree-browser.js'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE_NAME).then(c => c.addAll(SHELL_URLS)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);

  // Never cache API calls or non-GET requests. If the server is down, surface
  // the real network failure to the app instead of returning an invalid cache
  // miss as a Response.
  if (e.request.method !== 'GET' || url.pathname.startsWith('/api/')) {
    e.respondWith(fetch(e.request));
    return;
  }

  // Network-first for static shell assets; fall back to cache only if present.
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res && res.ok) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request).then(cached => cached || Response.error()))
  );
});
