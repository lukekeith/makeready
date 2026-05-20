<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin Login — MakeReady</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #1a1d28;
            color: #fff;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
        }
        .login-card {
            background: #252936;
            border-radius: 16px;
            padding: 48px 40px;
            width: 100%;
            max-width: 400px;
            text-align: center;
        }
        .login-card__logo {
            width: 48px;
            height: 48px;
            margin: 0 auto 24px;
        }
        .login-card__title {
            font-size: 22px;
            font-weight: 600;
            margin-bottom: 8px;
        }
        .login-card__subtitle {
            font-size: 14px;
            color: rgba(255,255,255,0.5);
            margin-bottom: 32px;
        }
        .login-card__error {
            background: rgba(239,68,68,0.15);
            color: #ef4444;
            font-size: 13px;
            padding: 10px 14px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .google-btn {
            display: inline-flex;
            align-items: center;
            gap: 10px;
            padding: 12px 28px;
            background: #fff;
            color: #1a1d28;
            font-size: 15px;
            font-weight: 500;
            border: none;
            border-radius: 8px;
            cursor: pointer;
            text-decoration: none;
            transition: background 0.15s;
        }
        .google-btn:hover { background: #f0f0f0; }
        .google-btn svg { width: 20px; height: 20px; }
    </style>
</head>
<body>
    <div class="login-card">
        <img src="/logo-mark.svg" alt="MakeReady" class="login-card__logo">
        <h1 class="login-card__title">Leader Login</h1>
        <p class="login-card__subtitle">Sign in with your Google account to manage your groups.</p>

        @if($error ?? false)
            <div class="login-card__error">{{ $error }}</div>
        @endif

        <a href="{{ route('admin.auth.google') }}" class="google-btn">
            <svg viewBox="0 0 24 24"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>
            Sign in with Google
        </a>
    </div>
</body>
</html>
