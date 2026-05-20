# Phase 1: Foundation + Compliance - Research

**Researched:** 2026-03-16
**Domain:** Laravel 12 scaffolding, PHP-FPM + Nginx on Railway, transparent cookie proxy, Blade compliance pages
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Repo Strategy**
- Archive existing React code on `archive/react-spa` branch before wiping
- Wipe main branch and initialize fresh Laravel project in root
- Preserve .planning/ directory through the wipe (copy out, wipe, copy back)
- Git history of React app preserved on archive branch for reference

**Architecture (No Inertia, No Node)**
- Blade templates for all page rendering (pure PHP server-side)
- Vue.js as client-side interactive islands (compiled by Vite at build time only)
- No Inertia.js — traditional Laravel routing with Blade views
- No Node.js runtime in production — Vite runs only during `npm run build`
- No Tailwind CSS — existing SCSS/BEM styles migrated to Laravel Vite pipeline

**Session & Auth Flow**
- Transparent cookie proxy: Laravel forwards API session cookies between browser and API
- No Laravel-side session for auth — API manages all session state via cookies
- All API calls go through Laravel controllers (including phone verification send/verify)
- `POST /api/members/confirm-verification` sets session cookie on response — Laravel must forward this cookie back to browser
- `GET /api/members/session` checks auth status via cookie — Laravel uses this to gate protected routes
- Auth check happens in Laravel middleware that calls `/api/members/session` and passes result to views

**Compliance Page Content**
- Rewrite /privacy and /terms fresh using TWILIO_A2P_COMPLIANCE.md as source of truth
- Full app layout (shared Blade layout with navigation/footer) — not minimal standalone
- Pure Blade templates (no Vue/Inertia) — content visible in raw HTML for crawlers
- Shared Blade layout between compliance pages and the rest of the app
- /sms-opt-in shows a live demo mockup of the join page with unchecked consent checkbox (not functional, visual proof for Twilio)

**Deployment**
- Custom Dockerfile with PHP-FPM + Nginx (no Octane, no Node)
- Standard Laravel deployment: `composer install`, `npm run build` (Vite compiles assets), `php artisan` commands
- Railway deployment via CI/CD (GitHub Actions, matching current workflow)
- Environment variables: API URL, app key, session config

### Claude's Discretion
- Nginx configuration details
- Laravel middleware implementation for auth proxy
- Vite configuration for Vue + SCSS compilation
- Exact Dockerfile structure and base images
- How to structure the cookie forwarding in the Http client

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| FOUND-01 | Laravel 12 project initialized with Blade templates + Vue.js islands + Vite (no Tailwind, no Inertia) | Standard `laravel new` + `@vitejs/plugin-vue` + `sass` — all documented below |
| FOUND-02 | Blade templates render full HTML on all pages (SSR verified via curl) | Default Laravel/Blade behavior; verified by fetching any route with curl |
| FOUND-03 | Railway deployment working with custom Dockerfile (PHP-FPM + Nginx, no Node runtime) | Dockerfile pattern documented below; Railway accepts custom Dockerfiles |
| FOUND-04 | PHP API service layer wrapping all MakeReady API endpoints via Http facade | Laravel Http facade `withHeaders` + `withCookies` pattern documented below |
| FOUND-05 | Transparent cookie proxy forwarding API session cookies between browser and API | Cookie forwarding implementation documented; Set-Cookie passthrough pattern |
| FOUND-06 | Auth middleware checking member session via API and gating protected routes | Custom middleware pattern with Http facade API call documented below |
| COMP-01 | Server-rendered /privacy page (pure Blade) with required SMS third-party sharing statement | Exact required language from TWILIO_A2P_COMPLIANCE.md documented below |
| COMP-02 | Server-rendered /terms page (pure Blade) with CTIA disclosures, STOP/HELP in bold | Exact required language from TWILIO_A2P_COMPLIANCE.md documented below |
| COMP-03 | /sms-opt-in public page showing opt-in flow for Twilio campaign approval | Static Blade mockup; consent checkbox language documented below |
| COMP-04 | SMS consent checkbox in join flow enforced server-side (unchecked default, tracked) | Blade checkbox pattern documented; existing React join page referenced |
| INFR-01 | CI/CD pipeline updated for Laravel deployment to Railway | Existing GitHub Actions workflow rewritten; composer/build steps documented |
| INFR-02 | Environment variables configured (API URL, session config, etc.) | Required env vars listed in full below |
</phase_requirements>

---

## Summary

Phase 1 establishes the entire Laravel foundation and ships the highest-value compliance deliverables. The two distinct concerns — infrastructure (FOUND-01 through FOUND-06, INFR-01, INFR-02) and compliance pages (COMP-01 through COMP-04) — can proceed in parallel once the project skeleton exists, because compliance pages have no dependency on the cookie proxy or auth middleware.

The key technical insight for this phase is that Railway's default Railpack auto-detects Laravel and uses PHP-FPM + Caddy, but the locked decision requires a **custom Dockerfile with Nginx**. Railway will use a Dockerfile whenever one is present, overriding Railpack. This gives full control over the Nginx configuration for Laravel's `try_files` routing.

The cookie proxy is the highest-complexity item. Laravel's Http facade does not auto-forward browser cookies — the incoming `Cookie` header must be extracted manually and passed as a raw `Cookie` header on outgoing API calls. API responses containing `Set-Cookie` headers must be parsed and re-issued to the browser response. The Laravel `EncryptCookies` middleware must be configured to not encrypt the API session cookies (since they belong to the external API, not Laravel).

**Primary recommendation:** Initialize Laravel 12 with no starter kit, configure Vite for Vue + SCSS, write the Dockerfile (PHP-FPM + Nginx using Supervisor or S6 as process manager), verify Railway picks it up and serves `curl /` with real HTML, then implement the cookie proxy middleware and compliance Blade pages.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Laravel | 12.x | PHP framework, routing, Http facade, Blade | LTS; official recommendation for this use case |
| PHP | 8.3+ | Runtime | Laravel 12 minimum is PHP 8.2; use 8.3 for current stability |
| `laravel/framework` | 12.x | Pulled via `composer create-project` | Framework itself |
| `laravel-vite-plugin` | 1.x | Vite integration for Blade `@vite()` directive | Shipped with Laravel 12 |
| `@vitejs/plugin-vue` | 5.x | Compiles Vue SFCs at build time | Standard Vue + Vite integration |
| `sass` (sass-embedded) | 1.x | SCSS compilation in Vite pipeline | Same package used in current React repo |
| Nginx | 1.25+ | Web server routing PHP requests to FPM | Locked decision; official Laravel Nginx config documented |
| PHP-FPM | 8.3 | PHP process manager for Nginx | Required companion to Nginx |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Supervisor | 4.x | Process manager to run PHP-FPM + Nginx in single container | Inside Dockerfile — keeps both processes alive |
| `guzzlehttp/guzzle` | 7.x | Underlies Laravel Http facade | Already a Laravel dependency; use via Http facade, not directly |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom Dockerfile | Railway Railpack (auto-detect) | Railpack uses Caddy, not Nginx — locked decision requires Nginx |
| Supervisor | S6 Overlay | S6 is lighter but less familiar; Supervisor is the community standard for PHP containers |
| Manual cookie forwarding | Package `jespanag/laravel-proxy-helper` | Package adds dependency for a problem solvable in ~30 lines of controller code |

**Installation (after `laravel new`):**

```bash
# PHP dependencies — no extras needed for Phase 1 (Http facade is in laravel/framework)
composer install

# Node dependencies
npm install --save-dev @vitejs/plugin-vue sass
```

---

## Architecture Patterns

### Recommended Project Structure

```
/ (repo root, wiped and re-initialized as Laravel)
├── .planning/           # Preserved through wipe
├── .github/
│   └── workflows/
│       └── ci.yml       # Rewritten for Laravel
├── app/
│   ├── Http/
│   │   ├── Controllers/
│   │   │   ├── ComplianceController.php   # /privacy, /terms, /sms-opt-in
│   │   │   └── HomeController.php         # Landing page
│   │   ├── Middleware/
│   │   │   └── CheckMemberSession.php     # FOUND-06 auth gate
│   │   └── Services/                      # Could also live at app/Services/
│   │       └── ApiService.php             # FOUND-04 HTTP facade wrapper
├── resources/
│   ├── views/
│   │   ├── layouts/
│   │   │   └── app.blade.php              # Shared layout (nav, footer)
│   │   ├── compliance/
│   │   │   ├── privacy.blade.php          # COMP-01
│   │   │   ├── terms.blade.php            # COMP-02
│   │   │   └── sms-opt-in.blade.php       # COMP-03
│   │   └── home.blade.php                 # Public landing
│   ├── css/
│   │   └── app.scss                       # SCSS entry point (BEM styles)
│   └── js/
│       └── app.js                         # Vue + JS entry point
├── routes/
│   └── web.php                            # All route definitions
├── Dockerfile                             # FOUND-03 PHP-FPM + Nginx
├── nginx.conf                             # Nginx server block config
├── supervisord.conf                       # Supervisor config
├── vite.config.js                         # FOUND-01 Vite + Vue + SCSS
└── .env.example                           # INFR-02 env var documentation
```

### Pattern 1: Laravel 12 Project Initialization

**What:** Create a fresh Laravel 12 project with no starter kit (no Breeze, no Jetstream, no Tailwind).
**When to use:** The repo wipe step — run once.

```bash
# After wiping main branch, from repo root:
laravel new . --no-interaction --git=false --database=none
# Or via composer:
composer create-project laravel/laravel . "12.*" --prefer-dist
```

The `--database=none` flag skips SQLite setup. Since there is no local database, also remove the default `DB_*` env vars from `.env.example` and set `DB_CONNECTION=none` to suppress Eloquent connection errors.

### Pattern 2: Vite Configuration for Vue + SCSS

**What:** Configure Vite to compile Vue SFCs and SCSS in the Laravel asset pipeline.
**When to use:** `vite.config.js` in project root.

```javascript
// Source: https://laravel.com/docs/12.x/vite
import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.scss', 'resources/js/app.js'],
            refresh: true,
        }),
        vue({
            template: {
                transformAssetUrls: {
                    base: null,
                    includeAbsolute: false,
                },
            },
        }),
    ],
    resolve: {
        alias: {
            vue: 'vue/dist/vue.esm-bundler.js',
        },
    },
});
```

Blade layouts reference compiled assets with:

```blade
{{-- resources/views/layouts/app.blade.php --}}
@vite(['resources/css/app.scss', 'resources/js/app.js'])
```

### Pattern 3: Nginx Configuration for Laravel

**What:** Standard Nginx server block routing all requests through `public/index.php`.
**When to use:** `nginx.conf` file referenced in Dockerfile.

```nginx
# Source: https://laravel.com/docs/12.x/deployment
server {
    listen 80;
    server_name _;
    root /var/www/html/public;
    index index.php;

    charset utf-8;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ ^/index\.php(/|$) {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
```

Note: `fastcgi_pass 127.0.0.1:9000` connects to PHP-FPM running on TCP port 9000 within the same container. If using a Unix socket instead, adjust to `unix:/var/run/php/php8.3-fpm.sock`.

### Pattern 4: Dockerfile (PHP-FPM + Nginx + Supervisor)

**What:** Single-container Dockerfile running Nginx and PHP-FPM managed by Supervisor.
**When to use:** Repo root `Dockerfile`. Railway will detect it and use it over Railpack.

```dockerfile
FROM php:8.3-fpm-alpine

# Install system dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    nodejs \
    npm \
    git \
    curl \
    libpng-dev \
    libzip-dev \
    zip \
    unzip

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    opcache

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy application source
COPY . .

# Install PHP dependencies (production mode)
RUN composer install --optimize-autoloader --no-dev --no-interaction

# Install Node dependencies and compile assets
RUN npm ci && npm run build && rm -rf node_modules

# Set permissions
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Copy configuration files
COPY nginx.conf /etc/nginx/http.d/default.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# PHP-FPM listens on 9000, Nginx on 80
EXPOSE 80

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
```

**Supervisor config (`supervisord.conf`):**

```ini
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:php-fpm]
command=/usr/local/sbin/php-fpm -F
autostart=true
autorestart=true
stderr_logfile=/var/log/php-fpm.err.log
stdout_logfile=/var/log/php-fpm.out.log

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stderr_logfile=/var/log/nginx.err.log
stdout_logfile=/var/log/nginx.out.log
```

**IMPORTANT:** Node is needed inside the Dockerfile only during the `npm run build` step. After `rm -rf node_modules`, no Node runtime is left in the final image. This satisfies the "no Node runtime in production" constraint — Node is present only for the build step, not as a running process.

### Pattern 5: Transparent Cookie Proxy (ApiService)

**What:** Laravel controller calls the external API, forwarding the browser's session cookie and re-issuing any `Set-Cookie` headers back to the browser response.
**When to use:** All controllers that touch the MakeReady API.

```php
// app/Services/ApiService.php
namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class ApiService
{
    private string $baseUrl;

    public function __construct()
    {
        $this->baseUrl = config('services.makeready.url');
    }

    /**
     * Make an API GET request, forwarding browser cookies.
     */
    public function get(string $endpoint, Request $request): array
    {
        $response = Http::withHeaders([
            'Cookie'       => $request->header('Cookie', ''),
            'Content-Type' => 'application/json',
            'Accept'       => 'application/json',
        ])->get("{$this->baseUrl}{$endpoint}");

        return [
            'status'     => $response->status(),
            'body'       => $response->json(),
            'setCookies' => $response->header('Set-Cookie'),
        ];
    }

    /**
     * Make an API POST request, forwarding browser cookies.
     */
    public function post(string $endpoint, array $data, Request $request): array
    {
        $response = Http::withHeaders([
            'Cookie'       => $request->header('Cookie', ''),
            'Content-Type' => 'application/json',
            'Accept'       => 'application/json',
        ])->post("{$this->baseUrl}{$endpoint}", $data);

        return [
            'status'     => $response->status(),
            'body'       => $response->json(),
            'setCookies' => $response->header('Set-Cookie'),
        ];
    }
}
```

**Forwarding Set-Cookie back to browser in a controller:**

```php
// In any controller method returning a view or redirect
$result = $this->api->post('/api/members/confirm-verification', $payload, $request);

$laravelResponse = redirect('/home');

// Pass API Set-Cookie headers back to the browser
if ($result['setCookies']) {
    foreach ((array) $result['setCookies'] as $setCookieHeader) {
        $laravelResponse->withHeaders(['Set-Cookie' => $setCookieHeader]);
    }
}

return $laravelResponse;
```

**Critical detail:** The `EncryptCookies` middleware in `bootstrap/app.php` encrypts all cookies Laravel touches. API session cookies must be excluded so they are passed through unmodified:

```php
// bootstrap/app.php
->withMiddleware(function (Middleware $middleware): void {
    $middleware->encryptCookies(except: [
        'makeready_session',  // Replace with actual API cookie name
        'PHPSESSID',          // If the API uses PHP's default session name
    ]);
})
```

The actual API cookie name must be determined by inspecting a login response from `https://api.makeready.org`. The existing React app's `credentials: 'include'` pattern confirms cookies exist; the name needs to be verified during implementation.

### Pattern 6: Auth Middleware (FOUND-06)

**What:** Middleware that calls `GET /api/members/session` and redirects unauthenticated users to the public home.
**When to use:** Applied to all protected route groups.

```php
// app/Http/Middleware/CheckMemberSession.php
namespace App\Http\Middleware;

use App\Services\ApiService;
use Closure;
use Illuminate\Http\Request;

class CheckMemberSession
{
    public function __construct(private ApiService $api) {}

    public function handle(Request $request, Closure $next)
    {
        $result = $this->api->get('/api/members/session', $request);

        if ($result['status'] !== 200 || empty($result['body']['member'])) {
            return redirect('/');
        }

        // Make member data available to all views in this request
        view()->share('currentMember', $result['body']['member']);

        return $next($request);
    }
}
```

```php
// routes/web.php — protected route group
use App\Http\Middleware\CheckMemberSession;

Route::middleware([CheckMemberSession::class])->group(function () {
    Route::get('/home', [HomeController::class, 'index']);
    // ...other protected routes added in later phases
});

// Public routes — no middleware
Route::get('/', [HomeController::class, 'landing']);
Route::get('/privacy', [ComplianceController::class, 'privacy']);
Route::get('/terms', [ComplianceController::class, 'terms']);
Route::get('/sms-opt-in', [ComplianceController::class, 'smsOptIn']);
```

### Pattern 7: Shared Blade Layout

**What:** Single layout file used by all pages including compliance pages.
**When to use:** All Blade views extend this layout.

```blade
{{-- resources/views/layouts/app.blade.php --}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'MakeReady')</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body>
    @include('partials.navigation')

    <main>
        @yield('content')
    </main>

    @include('partials.footer')
</body>
</html>
```

```blade
{{-- resources/views/compliance/privacy.blade.php --}}
@extends('layouts.app')

@section('title', 'Privacy Policy — MakeReady')

@section('content')
<div class="PrivacyPage">
    <div class="PrivacyPage__container">
        <h1 class="PrivacyPage__heading">Privacy Policy</h1>
        {{-- Content from TWILIO_A2P_COMPLIANCE.md --}}
    </div>
</div>
@endsection
```

### Pattern 8: GitHub Actions CI for Laravel

**What:** Replace the existing Node-centric CI workflow with a PHP-aware one.
**When to use:** `.github/workflows/ci.yml` — rewrite as part of INFR-01.

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  build-and-test:
    name: Build & Test
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup PHP
        uses: shivammathur/setup-php@v2
        with:
          php-version: '8.3'
          extensions: mbstring, pdo, zip, gd, bcmath
          coverage: none

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Composer dependencies
        run: composer install --no-dev --no-interaction --optimize-autoloader

      - name: Install NPM dependencies and build assets
        run: npm ci && npm run build

      - name: Copy .env
        run: cp .env.example .env

      - name: Generate app key
        run: php artisan key:generate

      - name: Run PHP tests (Pest)
        run: php artisan test

  docker-build:
    name: Docker Build Check
    runs-on: ubuntu-latest
    needs: [build-and-test]

    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -t makeready-client:test .

      - name: Smoke test — Laravel /up health route
        run: |
          docker run -d -p 8080:80 \
            -e APP_KEY=base64:testkey123456789012345678901234== \
            -e APP_ENV=testing \
            -e API_URL=https://api.makeready.org \
            --name test-container makeready-client:test
          sleep 5
          curl -sf http://localhost:8080/up || exit 1
          docker stop test-container
```

### Anti-Patterns to Avoid

- **Putting `try_files` before `index.php` in Nginx:** Without `try_files $uri $uri/ /index.php?$query_string`, direct URL navigation returns 404 because Nginx won't find the file on disk.
- **Encrypting API session cookies:** Laravel's `EncryptCookies` middleware will corrupt external API cookies if they are not excluded. The API cannot decrypt Laravel's encryption.
- **Calling the API in Blade templates or views:** All API calls must happen in controllers. Views receive data as variables only.
- **Running `npm run dev` in the Dockerfile:** The dev server is not for production. `npm run build` compiles assets to `public/build/`, then `node_modules` is deleted.
- **Storing API URL in a hardcoded config value:** Must come from `.env` → `config/services.php` → accessed via `config('services.makeready.url')`.
- **Using `DB_CONNECTION` without setting it to `none`:** Without this, Laravel will throw database connection errors on boot even though no queries are made.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PHP process management in Docker | Custom init scripts | Supervisor | Handles restarts, log management, signal propagation |
| Vite asset versioning/cache-busting | Custom fingerprinting | `@vite()` directive | Laravel's plugin handles manifest, hot-reload, and versioned URLs |
| CSRF token injection | Custom meta tag + JS | Laravel's `@csrf` Blade directive | Built-in; already handles cookie + header patterns |
| Route caching in production | Custom router | `php artisan route:cache` | Laravel's built-in optimizer |
| View precompilation | Custom Blade compiler | `php artisan view:cache` | Built-in optimizer |

**Key insight:** Laravel's built-in deployment commands (`php artisan optimize`, `route:cache`, `view:cache`) must be run in the Dockerfile after `composer install` — they are not optional performance extras, they are correctness requirements for production.

---

## Common Pitfalls

### Pitfall 1: EncryptCookies Corrupts API Session Cookie
**What goes wrong:** The API sets a session cookie on the browser. On subsequent requests, Laravel's `EncryptCookies` middleware attempts to decrypt it, fails, and strips the cookie before forwarding. The API sees no cookie and returns 401.
**Why it happens:** Laravel encrypts all cookies by default as a security measure. It does not know which cookies belong to external APIs.
**How to avoid:** Explicitly exclude the API cookie name(s) in `bootstrap/app.php` `encryptCookies(except: [...])`.
**Warning signs:** Auth middleware always redirects even after successful login; API session checks return 401 despite user having just logged in.

### Pitfall 2: `Set-Cookie` Header Not Forwarded to Browser
**What goes wrong:** `POST /api/members/confirm-verification` returns a session cookie in `Set-Cookie`. Laravel reads the API response body but the `Set-Cookie` header is not propagated to the browser response. The browser never stores the session cookie. All subsequent authenticated API calls return 401.
**Why it happens:** Laravel's `Http` facade response `.json()` method only returns the body. Headers require explicit handling via `.header('Set-Cookie')`.
**How to avoid:** Capture `Set-Cookie` from API response and call `->withHeaders(['Set-Cookie' => ...])` on the Laravel response before returning it.
**Warning signs:** Login appears to succeed (no error shown) but the next page load redirects to login again.

### Pitfall 3: Railway Ignores Custom Dockerfile and Uses Railpack
**What goes wrong:** Railway's Railpack detects PHP and uses its own Caddy-based PHP configuration instead of the custom Dockerfile.
**Why it happens:** If Railway's auto-detection fires before reading the Dockerfile, it may choose Railpack. Railway documentation states it will always prefer a Dockerfile if one is present — but this must be verified.
**How to avoid:** Confirm in Railway dashboard that the service is set to "Dockerfile" build mode, not Railpack/Nixpacks. Add a `railway.toml` to explicitly specify:
  ```toml
  [build]
  builder = "dockerfile"
  ```
**Warning signs:** Deployment succeeds but `docker build` log shows no Supervisor/Nginx step; container serves from a different web server than expected.

### Pitfall 4: `DB_CONNECTION` Causes Boot Errors
**What goes wrong:** Laravel tries to connect to a database on boot (or when caching config). With no database configured, connection errors halt the application.
**Why it happens:** Laravel defaults assume a database exists. Some Laravel internals attempt a DB connection during bootstrapping.
**How to avoid:** Set `DB_CONNECTION=sqlite` with `:memory:` in `.env`, or completely disable Eloquent. The simplest safe setting is to leave SQLite configured (it requires no server) and simply never call any Eloquent models. Set `DB_DATABASE=:memory:` or point to a temp file.
**Warning signs:** `php artisan optimize` or `php artisan route:cache` crashes with PDO/database connection error.

### Pitfall 5: Compliance Pages Not Crawlable Due to Partial Blade
**What goes wrong:** CSS-heavy pages look blank to crawlers if the `@vite()` directive refers to a built asset that does not exist in the Docker image (e.g., `.gitignore` excludes `public/build/`).
**Why it happens:** The Vite build step runs in the Dockerfile, but if the Dockerfile caches layers incorrectly, old assets are used.
**How to avoid:** Ensure `npm run build` runs AFTER `COPY . .` in the Dockerfile. Verify `public/build/` is in `.gitignore` (correct) and that the Dockerfile build creates it freshly every time.
**Warning signs:** `curl https://app.makeready.org/privacy` returns HTML with `<link href="/build/app-XXXX.css">` but the CSS file returns 404.

### Pitfall 6: Cookie Header Contains Laravel-Encrypted Cookies Sent to External API
**What goes wrong:** When forwarding `$request->header('Cookie')` to the API, the string may include Laravel's own encrypted cookies (session, XSRF-TOKEN). The API receives garbage data in the Cookie header.
**Why it happens:** Laravel stores its own encrypted values in cookies. Forwarding the entire Cookie header sends both Laravel's and the API's cookies.
**How to avoid:** Extract only the API session cookie by name from the Cookie header rather than forwarding the entire string. Use `$request->cookie('api_session_cookie_name')` to get just that cookie value.
**Warning signs:** API returns errors about malformed session identifiers.

---

## Code Examples

Verified patterns from official and community sources:

### Registering a Custom Middleware Alias

```php
// Source: https://laravel.com/docs/12.x/middleware
// bootstrap/app.php
->withMiddleware(function (Middleware $middleware): void {
    $middleware->alias([
        'member.auth' => \App\Http\Middleware\CheckMemberSession::class,
    ]);
    $middleware->encryptCookies(except: [
        'makeready_session', // Actual name TBD from API inspection
    ]);
})
```

### Env → Config Chain for API URL

```php
// config/services.php
return [
    'makeready' => [
        'url' => env('API_URL', 'https://api.makeready.org'),
    ],
];
```

```env
# .env (development)
API_URL=https://api.makeready.org
APP_KEY=base64:...
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost
SESSION_DRIVER=cookie
LOG_CHANNEL=stderr
```

### Required Privacy Policy Language (COMP-01)

From `TWILIO_A2P_COMPLIANCE.md` — verbatim required statement:

```
"No mobile information will be shared with third parties/affiliates for
marketing/promotional purposes."
```

This exact sentence must appear in the `/privacy` Blade template. The page must also include: what data is collected (phone numbers), how data is used, and confirmation that info won't be shared with third parties for marketing purposes.

### Required Terms of Service Language (COMP-02)

From `TWILIO_A2P_COMPLIANCE.md`:

```blade
{{-- Must be in /terms Blade template --}}
<p>Text <strong>STOP</strong> to opt out at any time.</p>
<p>Text <strong>HELP</strong> for support.</p>
<p>Message and data rates may apply.</p>
<p>Message frequency varies based on group activity.</p>
```

Full requirements:
- Program name: "MakeReady"
- Description of the SMS messaging program
- Message frequency statement
- "Message and data rates may apply"
- STOP instructions **in bold**
- HELP instructions **in bold**
- Support contact info (email)

### /sms-opt-in Static Mockup (COMP-03)

The page must show the consent checkbox as it appears in the join flow — **visually demonstrating** that it is unchecked by default. It does not need to be functional (no form submission). Content from `TWILIO_A2P_COMPLIANCE.md`:

```blade
{{-- resources/views/compliance/sms-opt-in.blade.php --}}
@extends('layouts.app')
@section('content')
<div class="SmsOptIn">
    <h1>How we obtain SMS consent</h1>
    <p>When joining a MakeReady group, members see the following opt-in checkbox:</p>

    <div class="SmsOptIn__demo">
        <label class="SmsOptIn__label">
            <input type="checkbox" disabled>
            {{-- NOT checked --}}
            I agree to receive text messages from MakeReady for group-related
            events and daily studies. Msg &amp; data rates may apply.
            Reply STOP to opt out.
        </label>
    </div>

    <p>The checkbox is not pre-checked. Members must actively check it before joining.</p>
    <p>View our <a href="/privacy">Privacy Policy</a> and <a href="/terms">Terms of Service</a>.</p>
</div>
@endsection
```

---

## Required Environment Variables (INFR-02)

Complete list of environment variables needed in Railway dashboard:

| Variable | Value | Purpose |
|----------|-------|---------|
| `APP_KEY` | `base64:...` (generated via `php artisan key:generate`) | Encryption key — REQUIRED |
| `APP_ENV` | `production` | Enables production optimizations |
| `APP_DEBUG` | `false` | Hides error details from users |
| `APP_URL` | `https://app.makeready.org` | Used in URL generation |
| `API_URL` | `https://api.makeready.org` | External API base URL |
| `LOG_CHANNEL` | `stderr` | Railway streams stderr to logs dashboard |
| `SESSION_DRIVER` | `cookie` | No Redis needed; cookie-based |
| `SESSION_SECURE_COOKIE` | `true` | HTTPS only |
| `SESSION_SAME_SITE` | `lax` | CSRF protection |
| `DB_CONNECTION` | `sqlite` | Prevents Eloquent boot errors; no DB used |
| `DB_DATABASE` | `:memory:` | SQLite in-memory; never actually queried |

Note: `APP_KEY` cannot be committed to git. Generate it locally with `php artisan key:generate --show` and set it in Railway dashboard directly.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Nixpacks (Railway's old builder) | Railpack (Railway's new builder) | 2025 | `nixpacks.toml` replaced by `railpack.json`; Dockerfiles still work as override |
| Laravel Mix (webpack) | Laravel Vite plugin | Laravel 9 (2022) | `vite.config.js` replaces `webpack.mix.js`; `@vite()` replaces `mix()` Blade directive |
| PHP 8.1 minimum (Laravel 10) | PHP 8.2+ minimum (Laravel 12) | 2024 | Use PHP 8.3 in Dockerfile |
| `bootstrap/app.php` as plain config | Fluent builder API | Laravel 11 (2024) | Middleware, routing registered via `->withMiddleware()` and `->withRouting()` |

**Deprecated/outdated:**
- `webpack.mix.js` / Laravel Mix: Completely removed in Laravel 12 projects. Use `vite.config.js`.
- `App\Http\Kernel.php` for middleware registration: Replaced by `bootstrap/app.php` fluent API in Laravel 11+.
- `nixpacks.toml` for Railway PHP: Nixpacks is deprecated; Railpack is the new default (custom Dockerfiles override both).

---

## Open Questions

1. **Exact API session cookie name**
   - What we know: The MakeReady API at `https://api.makeready.org` sets a session cookie when `POST /api/members/confirm-verification` succeeds
   - What's unclear: The cookie name (could be `connect.sid`, `PHPSESSID`, `session`, or custom)
   - Recommendation: During implementation, make a test API call and inspect the `Set-Cookie` response header to get the actual name before configuring `encryptCookies(except: [...])`

2. **Railway Dockerfile detection vs Railpack**
   - What we know: Railway documentation states Dockerfiles take precedence; Railpack is the fallback
   - What's unclear: Whether Railway's UI requires manual selection of "Dockerfile" build mode or if auto-detection is reliable
   - Recommendation: After pushing the Dockerfile, verify in Railway dashboard that the build log shows "Building from Dockerfile" — if not, add `railway.toml` with `[build] builder = "dockerfile"`

3. **PHP extension requirements for Http facade**
   - What we know: Laravel Http facade requires cURL extension; basic set is `mbstring, pdo, zip, gd, bcmath`
   - What's unclear: Whether `curl` extension needs explicit install on `php:8.3-fpm-alpine` (some Alpine images include it)
   - Recommendation: Add `curl` to `docker-php-ext-install` to be safe; if it errors, it's already present

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Pest PHP (via `pestphp/pest` — Laravel 12 default test runner) |
| Config file | `phpunit.xml` (Pest runs on top of PHPUnit config) |
| Quick run command | `php artisan test --filter ComplianceTest` |
| Full suite command | `php artisan test` |

Pest is Laravel 12's default testing framework (included in `composer.json` dev dependencies). No additional setup needed.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | Laravel boots, Vite config loads, `/` returns 200 | Feature (HTTP) | `php artisan test --filter ProjectBootTest` | ❌ Wave 0 |
| FOUND-02 | `GET /` returns full HTML (not blank div) via curl | Feature (HTTP) | `php artisan test --filter SsrHtmlTest` | ❌ Wave 0 |
| FOUND-03 | Docker image builds without error | Manual / CI | `docker build -t test .` in GitHub Actions | ❌ Wave 0 (CI step) |
| FOUND-04 | ApiService::get() makes request to correct URL with Cookie header | Unit | `php artisan test --filter ApiServiceTest` | ❌ Wave 0 |
| FOUND-05 | Set-Cookie from API response appears in Laravel response | Feature (HTTP) | `php artisan test --filter CookieProxyTest` | ❌ Wave 0 |
| FOUND-06 | Unauthenticated request to protected route redirects to `/` | Feature (HTTP) | `php artisan test --filter AuthMiddlewareTest` | ❌ Wave 0 |
| COMP-01 | `GET /privacy` contains required Twilio third-party statement | Feature (HTTP) | `php artisan test --filter PrivacyPageTest` | ❌ Wave 0 |
| COMP-02 | `GET /terms` contains STOP/HELP in bold HTML | Feature (HTTP) | `php artisan test --filter TermsPageTest` | ❌ Wave 0 |
| COMP-03 | `GET /sms-opt-in` contains unchecked checkbox HTML | Feature (HTTP) | `php artisan test --filter SmsOptInPageTest` | ❌ Wave 0 |
| COMP-04 | `/sms-opt-in` checkbox input has no `checked` attribute | Feature (HTTP) | `php artisan test --filter SmsOptInPageTest` | ❌ Wave 0 (same file) |
| INFR-01 | CI workflow runs `composer install`, `npm run build`, `php artisan test` | Manual / CI | GitHub Actions run | ❌ Wave 0 (workflow file) |
| INFR-02 | Required env vars are documented in `.env.example` | Manual | Code review | ❌ Wave 0 (env file) |

### Key Test Patterns for Laravel Feature Tests

```php
// tests/Feature/ComplianceTest.php (Wave 0 creation)
test('privacy page returns 200 and contains required Twilio statement', function () {
    $response = $this->get('/privacy');
    $response->assertStatus(200);
    $response->assertSee('No mobile information will be shared with third parties');
});

test('terms page contains STOP and HELP in bold', function () {
    $response = $this->get('/terms');
    $response->assertStatus(200);
    $response->assertSee('<strong>STOP</strong>', false);
    $response->assertSee('<strong>HELP</strong>', false);
});

test('sms-opt-in page shows unchecked checkbox', function () {
    $response = $this->get('/sms-opt-in');
    $response->assertStatus(200);
    $response->assertSee('<input type="checkbox"', false);
    $response->assertDontSee('checked');
});
```

### Sampling Rate

- **Per task commit:** `php artisan test --filter` on the specific requirement being implemented
- **Per wave merge:** `php artisan test` (full suite)
- **Phase gate:** Full suite green + `docker build` succeeds + `curl /privacy` returns HTML with required text

### Wave 0 Gaps

- [ ] `tests/Feature/ComplianceTest.php` — covers COMP-01, COMP-02, COMP-03, COMP-04
- [ ] `tests/Feature/RoutingTest.php` — covers FOUND-01, FOUND-02
- [ ] `tests/Unit/ApiServiceTest.php` — covers FOUND-04, FOUND-05
- [ ] `tests/Feature/AuthMiddlewareTest.php` — covers FOUND-06
- [ ] `phpunit.xml` — default Laravel config; verify present after `laravel new`
- [ ] Pest install: `composer require pestphp/pest --dev` (included in `laravel new` but verify)

---

## Sources

### Primary (HIGH confidence)
- [Laravel 12 Docs: Vite Asset Bundling](https://laravel.com/docs/12.x/vite) — `@vite()` directive, SCSS setup, Vue plugin config
- [Laravel 12 Docs: Deployment](https://laravel.com/docs/12.x/deployment) — Nginx config, Artisan optimize commands, PHP requirements
- [Laravel 12 Docs: Middleware](https://laravel.com/docs/12.x/middleware) — `handle()` signature, registration via `bootstrap/app.php`
- [Laravel 12 Docs: HTTP Responses](https://laravel.com/docs/12.x/responses) — `->cookie()`, `->withHeaders()` for Set-Cookie forwarding
- [Railway Laravel Deployment Guide](https://docs.railway.com/guides/laravel) — PHP-FPM + Caddy auto-detection, env vars, Railpack
- `TWILIO_A2P_COMPLIANCE.md` — Verbatim required compliance language for /privacy, /terms, /sms-opt-in

### Secondary (MEDIUM confidence)
- [Railway Help Station: Nginx with PHP-FPM](https://station.railway.com/questions/nginx-with-php-fpm-2a7412f3) — Custom Nginx + FPM in single container
- [Laravel framework discussion #43578](https://github.com/laravel/framework/discussions/43578) — Http facade cookie forwarding limitations and workarounds
- [Laravel 12 Docker Blueprint on DEV Community](https://dev.to/mufthi_ryanda_84ea0d65262/the-laravel-12-docker-blueprint-i-wish-i-had-nginx-php-fpm-small-images-clean-cicd-and-4ai5) — Multi-stage Dockerfile with Nginx + PHP-FPM + Supervisor
- [Railpack vs Nixpacks 2026](https://www.bitdoze.com/nixpacks-vs-railpack/) — Railpack is the current Railway default; Nixpacks deprecated

### Tertiary (LOW confidence)
- [GitHub: bkuhl/fpm-nginx](https://github.com/bkuhl/fpm-nginx) — Single container FPM + Nginx reference (uses S6 Overlay as alternative to Supervisor)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Laravel 12, Vite, PHP-FPM, Nginx all have official docs
- Architecture: HIGH — Blade routing, middleware patterns, and Http facade are core Laravel features
- Pitfalls: HIGH — Cookie encryption conflict is documented in Laravel source; Railway Dockerfile override is documented behavior
- Compliance content: HIGH — Sourced directly from `TWILIO_A2P_COMPLIANCE.md` in this repo

**Research date:** 2026-03-16
**Valid until:** 2026-04-16 (stable libraries; Railway build pipeline may change faster)
