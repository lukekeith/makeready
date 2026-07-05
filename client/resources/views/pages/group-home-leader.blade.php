{{-- resources/views/pages/group-home-leader.blade.php --}}
{{-- Capture-only harness for the LEADER group-home twin. Renders the
     GroupHomeLeader component full-bleed (no .capture-wrap gutter) so the
     Compare tool can screenshot it apples-to-apples against the iPhone
     Pages/Manage/Group/GroupHomePage.swift leader screen. This is NOT the
     production member group home — that lives at pages/group-home.blade.php and
     is served by the real `group.home` route, untouched. Driven by the
     group-home compare adapter: data = { component, componentProps }. --}}
@php
    $component      = $component      ?? 'GroupHomeLeader';
    $componentProps = $componentProps ?? [];
@endphp
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Group Home (Leader) — Capture</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
    <style>
        html, body { margin: 0; background: #0d101a; }
        /* Full-bleed: a page twin fills the device frame edge-to-edge (the
           toolbar/content carry their own insets), unlike the component harness
           which adds a 16px gutter. */
        .capture-page, .capture-page > * { width: 100%; }
    </style>
</head>
<body>
    <div class="capture-page">
        <div
            data-vue="ComponentCapture"
            data-props='@json(['component' => $component, 'props' => $componentProps], JSON_HEX_APOS | JSON_HEX_QUOT)'
        ></div>
    </div>
</body>
</html>
