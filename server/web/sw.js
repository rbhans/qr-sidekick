const CACHE_NAME = 'qr-sidekick-v2';
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
  // Network-first for everything; fall back to cache only if network fails.
  // Keeps offline support while ensuring updates show up without manual cache busts.
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res && res.ok && e.request.method === 'GET' && !e.request.url.includes('/api/')) {
          const clone = res.clone();
          caches.open(CACHE_NAME).then(c => c.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});
