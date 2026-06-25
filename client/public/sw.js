/*
 * MakeReady service worker — minimal app-shell + static caching.
 * Scope: served from "/", so it controls the whole origin. We deliberately
 * NEVER cache API or admin traffic (network-only) and keep the cache small.
 *
 * Strategy:
 *   - navigations (HTML)      → network-first, fall back to cache, then offline.html
 *   - static assets           → stale-while-revalidate (build/, icons/, images/, fonts)
 *   - /api/*, /admin/*        → network-only (never cached)
 *
 * Bump CACHE_VERSION to invalidate old caches on deploy.
 */
const CACHE_VERSION = 'mr-v1';
const APP_SHELL = `${CACHE_VERSION}-shell`;
const RUNTIME = `${CACHE_VERSION}-runtime`;

// Precached offline shell + brand assets (hashed build assets are cached at runtime).
const PRECACHE_URLS = [
  '/offline.html',
  '/logo-mark.svg',
  '/icons/pwa/icon-192.png',
  '/icons/pwa/icon-512.png',
  '/manifest.webmanifest',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(APP_SHELL).then((cache) => cache.addAll(PRECACHE_URLS)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((k) => !k.startsWith(CACHE_VERSION)).map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

function isStaticAsset(url) {
  return (
    url.pathname.startsWith('/build/') ||
    url.pathname.startsWith('/icons/') ||
    url.pathname.startsWith('/images/') ||
    url.pathname.startsWith('/themes/') ||
    /\.(?:css|js|woff2?|ttf|png|jpg|jpeg|svg|webp|ico)$/.test(url.pathname)
  );
}

function isBypassed(url) {
  // Never cache app/admin data or auth — always go to network.
  return (
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('/admin/') ||
    url.pathname.startsWith('/auth/') ||
    url.pathname.startsWith('/login') ||
    url.pathname.startsWith('/logout')
  );
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return; // let cross-origin (CDN/API) pass through
  if (isBypassed(url)) return; // network-only

  // HTML navigations: network-first → cache → offline shell.
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(RUNTIME).then((cache) => cache.put(request, copy));
          return response;
        })
        .catch(() =>
          caches.match(request).then((cached) => cached || caches.match('/offline.html'))
        )
    );
    return;
  }

  // Static assets: stale-while-revalidate.
  if (isStaticAsset(url)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        const network = fetch(request)
          .then((response) => {
            const copy = response.clone();
            caches.open(RUNTIME).then((cache) => cache.put(request, copy));
            return response;
          })
          .catch(() => cached);
        return cached || network;
      })
    );
  }
});

// Allow the page to trigger an immediate activation after an update.
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});
