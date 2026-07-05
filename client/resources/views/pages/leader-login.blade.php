<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Sign in — MakeReady</title>
    <link rel="icon" type="image/svg+xml" href="/logo-mark.svg">
    {{-- PWA: manifest + theme + apple/home-screen meta (scope /admin) --}}
    @include('partials.pwa-admin')
    <style>
        /* Standalone, mobile-first leader sign-in. Brand values mirror the app's
           design tokens (--color-canvas #0d101a, brandPrimary #6c47ff). */
        * { margin: 0; padding: 0; box-sizing: border-box; }
        :root { --canvas: #0d101a; --brand: #6c47ff; }
        /* Full-bleed: the /admin/* surface never puts padding on <body>, and never
           scrolls horizontally. The gutter lives on the inner container. */
        html, body {
            margin: 0;
            padding: 0;
            width: 100%;
            max-width: 100%;
            overflow-x: hidden;
            background: var(--canvas);
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', Roboto, sans-serif;
            color: #fff;
            min-height: 100dvh;
            display: flex;
            flex-direction: column;
            justify-content: center;
        }
        .login {
            width: 100%;
            max-width: 420px;
            margin: 0 auto;
            padding: 24px max(20px, env(safe-area-inset-right)) max(32px, env(safe-area-inset-bottom)) max(20px, env(safe-area-inset-left));
            display: flex;
            flex-direction: column;
            align-items: center;
            text-align: center;
            flex: 1;
            justify-content: center;
        }
        .login__logo { width: 64px; height: 64px; margin-bottom: 28px; }
        .login__title { font-size: 28px; font-weight: 700; letter-spacing: -0.02em; }
        .login__subtitle {
            font-size: 15px;
            line-height: 1.4;
            color: rgba(255, 255, 255, 0.5);
            margin-top: 10px;
            max-width: 17rem;
        }
        .login__error {
            width: 100%;
            background: rgba(239, 68, 68, 0.15);
            color: #ff6b6b;
            font-size: 13px;
            line-height: 1.4;
            padding: 12px 14px;
            border-radius: 12px;
            margin-top: 24px;
        }
        .login__actions { width: 100%; margin-top: 32px; }
        .google-btn {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            width: 100%;
            padding: 16px 24px;
            background: #fff;
            color: #1a1d28;
            font-size: 16px;
            font-weight: 600;
            border: none;
            border-radius: 14px;
            cursor: pointer;
            text-decoration: none;
            -webkit-tap-highlight-color: transparent;
            transition: opacity 0.15s;
        }
        .google-btn:active { opacity: 0.85; }
        .google-btn svg { width: 20px; height: 20px; }
        .login__footnote {
            font-size: 12px;
            color: rgba(255, 255, 255, 0.3);
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <main class="login">
        <img src="/logo-mark.svg" alt="MakeReady" class="login__logo">
        <h1 class="login__title">MakeReady</h1>
        <p class="login__subtitle">Sign in to manage your groups, studies, and members.</p>

        @if($error ?? false)
            <div class="login__error">{{ $error }}</div>
        @endif

        <div class="login__actions">
            <a href="{{ route('admin.auth.google') }}" class="google-btn">
                <svg viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
                Continue with Google
            </a>
            <p class="login__footnote">For group leaders only.</p>
        </div>
    </main>
</body>
</html>
