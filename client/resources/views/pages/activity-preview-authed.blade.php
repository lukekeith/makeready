{{-- resources/views/pages/activity-preview-authed.blade.php --}}
{{-- Authenticated canonical preview for any activity type. --}}
{{-- preview-entry.ts detects the type and mounts the correct player. --}}
{{-- Mounted by PreviewController::authenticatedActivityPreview. Loaded directly by the iPhone WKWebView. --}}
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover"
  >
  <title>{{ $activityData['title'] ?? 'Activity Preview' }} — MakeReady</title>
  <style>
    *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }
    html {
      font-size: clamp(10px, 3vmin, 13px);
      font-family: -apple-system, BlinkMacSystemFont, "Open Sans", sans-serif;
    }
    html, body, #preview-app {
      width: 100%; height: 100%;
      background: #0a0a0f;
      overflow: hidden;
      -webkit-user-select: none;
      user-select: none;
    }
  </style>
  @vite('resources/js/preview-entry.ts')
</head>
<body>
  <script>window.__PREVIEW_DATA__ = @json(['activity' => $activityData]);</script>
  <div id="preview-app"></div>
</body>
</html>
