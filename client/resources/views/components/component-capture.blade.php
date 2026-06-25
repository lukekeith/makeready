{{-- resources/views/components/component-capture.blade.php --}}
{{-- Capture-only harness: renders ONE design-system component in isolation on
     the app canvas, fed arbitrary props, so the Compare tool can screenshot it
     apples-to-apples against the iPhone build. Driven by CaptureController from
     a compare fixture: data = { component, componentProps }. --}}
@php
    $component       = $component       ?? 'CardStudy';
    $componentProps  = $componentProps  ?? [];
@endphp
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ $component }} — Component Capture</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
    <style>
        html, body { margin: 0; background: #0d101a; }
        /* 16px gutter on each side mirrors the iPhone component snapshot, so the
           component renders at the same intrinsic width (viewport − 32) on both. */
        .capture-wrap { display: flex; justify-content: center; padding: 16px; }
        .capture-wrap > * { width: 100%; }
    </style>
</head>
<body>
    <div class="capture-wrap">
        <div
            data-vue="ComponentCapture"
            data-props='@json(['component' => $component, 'props' => $componentProps])'
        ></div>
    </div>
</body>
</html>
