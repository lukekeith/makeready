{{-- resources/views/layouts/admin.blade.php --}}
{{-- Admin shell layout — no sidebar in Blade (sidebar lives in Vue AdminIsland) --}}
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <link rel="icon" type="image/svg+xml" href="/logo-mark.svg">
    <title>@yield('title', 'MakeReady Admin')</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body class="AdminBody">
    @yield('content')
</body>
</html>
