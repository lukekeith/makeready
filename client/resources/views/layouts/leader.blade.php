{{-- resources/views/layouts/leader.blade.php --}}
{{-- Mobile leader app shell (the new /admin). Dark, full-bleed, installable PWA —
     distinct from the legacy white desktop admin (layouts/admin). The LeaderBody
     class drives the full-bleed dark canvas + no-horizontal-scroll rules in app.scss. --}}
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <link rel="icon" type="image/svg+xml" href="/logo-mark.svg">
    <title>@yield('title', 'MakeReady')</title>
    @include('partials.pwa-admin')
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body class="LeaderBody">
    @yield('content')
</body>
</html>
