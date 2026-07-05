{{-- PWA head for the mobile leader app (/admin). Sibling of partials/pwa.blade.php
     (the member-facing PWA) but scoped to /admin via admin.webmanifest. Dark canvas
     (#0d101a) drives the theme/status bar. --}}

{{-- Web App Manifest (scope: /admin) --}}
<link rel="manifest" href="/admin.webmanifest">

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
  // Register the shared service worker, scoped to the leader app. Secure-context
  // only; browsers no-op otherwise. The SW treats /admin/* as network-only, so
  // this never caches admin/API traffic — it just makes the app installable.
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('/sw.js', { scope: '/admin' }).catch(function () {});
    });
  }
</script>
