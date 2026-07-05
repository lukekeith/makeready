{{-- resources/views/pages/leader-twin.blade.php --}}
{{-- Generic capture-only harness for the LEADER page twins. Renders a single
     leader-screen Vue component full-bleed (no .capture-wrap gutter) so the
     Compare tool can screenshot it apples-to-apples against the iPhone Manage/
     Main leader screens. NOT a production page — production member pages and the
     admin SPA are untouched. Driven by a compare adapter's toClient:
     data = { component, componentProps }. --}}
@php
    $component      = $component      ?? 'HomeDashboard';
    $componentProps = $componentProps ?? [];
@endphp
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $component }} (Leader) — Capture</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
    <style>
        html, body { margin: 0; background: #0d101a; min-height: 100%; }
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
