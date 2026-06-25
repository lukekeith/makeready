{{-- PWA head + bootstrap. Included by the member-facing layouts (app/home/auth)
     ONLY — never the admin layout (admin is light-themed and out of PWA scope).
     The dark canvas (#0d101a) drives the theme/status bar. --}}

{{-- Web App Manifest --}}
<link rel="manifest" href="/manifest.webmanifest">

{{-- Theme + standalone (dark canvas) --}}
<meta name="theme-color" content="#0d101a">
<meta name="color-scheme" content="dark">
<meta name="mobile-web-app-capable" content="yes">

{{-- iOS standalone / home-screen --}}
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="MakeReady">
<link rel="apple-touch-icon" href="/icons/pwa/apple-touch-icon.png">
<link rel="mask-icon" href="/logo-mark.svg" color="#6c47ff">

<script>
  // Register the service worker (secure-context only; browsers no-op otherwise).
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(function () {});
    });
  }

  // Capture the install prompt and offer a one-time, dismissible hint.
  (function () {
    var STORAGE_KEY = 'mr-install-dismissed';
    var deferred = null;

    window.addEventListener('beforeinstallprompt', function (e) {
      e.preventDefault();
      deferred = e;
      window.__mrInstallPrompt = deferred; // app code can trigger install too
      if (localStorage.getItem(STORAGE_KEY)) return;
      showHint();
    });

    window.addEventListener('appinstalled', function () {
      localStorage.setItem(STORAGE_KEY, '1');
      deferred = null;
      var el = document.getElementById('mr-install-hint');
      if (el) el.remove();
    });

    window.mrPromptInstall = function () {
      if (!deferred) return Promise.resolve(false);
      deferred.prompt();
      return deferred.userChoice.then(function (c) {
        deferred = null;
        return c && c.outcome === 'accepted';
      });
    };

    function showHint() {
      if (document.getElementById('mr-install-hint')) return;
      var bar = document.createElement('div');
      bar.id = 'mr-install-hint';
      bar.setAttribute('role', 'dialog');
      bar.style.cssText = [
        'position:fixed',
        'left:50%',
        'transform:translateX(-50%)',
        'bottom:calc(16px + env(safe-area-inset-bottom))',
        'z-index:1300',
        'width:min(480px,calc(100vw - 24px))',
        'display:flex',
        'align-items:center',
        'gap:12px',
        'padding:12px 16px',
        'border-radius:12px',
        'background:#191c25',
        'border:1px solid rgba(255,255,255,0.1)',
        'box-shadow:0 8px 24px rgba(0,0,0,0.45)',
        'color:#fff',
        'font:14px/1.4 "Open Sans",-apple-system,sans-serif'
      ].join(';');
      bar.innerHTML =
        '<img src="/icons/pwa/icon-192.png" alt="" width="32" height="32" style="border-radius:8px;flex-shrink:0">' +
        '<span style="flex:1">Add MakeReady to your home screen</span>' +
        '<button id="mr-install-yes" style="background:#6c47ff;color:#fff;border:0;border-radius:9999px;padding:8px 14px;font-weight:600;cursor:pointer">Install</button>' +
        '<button id="mr-install-no" aria-label="Dismiss" style="background:transparent;color:rgba(255,255,255,0.6);border:0;font-size:20px;cursor:pointer;padding:4px">&times;</button>';
      document.body.appendChild(bar);
      document.getElementById('mr-install-yes').onclick = function () {
        window.mrPromptInstall().finally(function () { bar.remove(); });
      };
      document.getElementById('mr-install-no').onclick = function () {
        localStorage.setItem(STORAGE_KEY, '1');
        bar.remove();
      };
    }
  })();
</script>
