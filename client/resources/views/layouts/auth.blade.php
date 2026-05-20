{{-- resources/views/layouts/auth.blade.php --}}
{{-- Full-screen centered layout for join flows, login, and public home --}}
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <link rel="icon" type="image/svg+xml" href="/logo-mark.svg">
    <title>@yield('title', 'MakeReady')</title>
    <meta name="description" content="@yield('description', 'MakeReady is an invite-only experience that facilitates personal growth through human connection, accountability, and study.')">

    {{-- Open Graph --}}
    <meta property="og:type" content="website">
    <meta property="og:title" content="@yield('og_title', 'MakeReady')">
    <meta property="og:description" content="@yield('og_description', 'Personal growth through human connection, accountability, and study.')">
    <meta property="og:image" content="@yield('og_image', url('/social-share.png'))">
    <meta property="og:url" content="{{ url()->current() }}">
    <meta property="og:site_name" content="MakeReady">

    {{-- Twitter/X --}}
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="@yield('og_title', 'MakeReady')">
    <meta name="twitter:description" content="@yield('og_description', 'Personal growth through human connection, accountability, and study.')">
    <meta name="twitter:image" content="@yield('og_image', url('/social-share.png'))">

    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body class="AuthPage">
    @if(request()->is('pages/*') || request()->is('privacy') || request()->is('terms') || request()->is('sms-terms') || request()->is('contact'))
        <x-layout.site-navbar />
    @endif
    @yield('content')
    <div data-vue="ModalProvider"></div>
</body>
</html>
