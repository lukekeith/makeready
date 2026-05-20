# Phase 1: Foundation + Compliance - Context

**Gathered:** 2026-03-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Scaffold a Laravel 12 app with Blade templates for server-rendered pages and Vue.js for interactive client-side islands. Deploy to Railway via custom Dockerfile (PHP-FPM + Nginx). Establish cookie-forwarding auth proxy to the external MakeReady API. Ship Twilio compliance pages (/privacy, /terms, /sms-opt-in) as pure Blade templates crawlable by bots.

**Architecture change from research:** No Inertia.js, no Node runtime. Blade templates handle all SSR. Vue.js compiles at build time via Vite and mounts as interactive islands on pages that need it.

</domain>

<decisions>
## Implementation Decisions

### Repo Strategy
- Archive existing React code on `archive/react-spa` branch before wiping
- Wipe main branch and initialize fresh Laravel project in root
- Preserve .planning/ directory through the wipe (copy out, wipe, copy back)
- Git history of React app preserved on archive branch for reference

### Architecture (No Inertia, No Node)
- Blade templates for all page rendering (pure PHP server-side)
- Vue.js as client-side interactive islands (compiled by Vite at build time only)
- No Inertia.js — traditional Laravel routing with Blade views
- No Node.js runtime in production — Vite runs only during `npm run build`
- No Tailwind CSS — existing SCSS/BEM styles migrated to Laravel Vite pipeline

### Session & Auth Flow
- Transparent cookie proxy: Laravel forwards API session cookies between browser and API
- No Laravel-side session for auth — API manages all session state via cookies
- All API calls go through Laravel controllers (including phone verification send/verify)
- `POST /api/members/confirm-verification` sets session cookie on response — Laravel must forward this cookie back to browser
- `GET /api/members/session` checks auth status via cookie — Laravel uses this to gate protected routes
- Auth check happens in Laravel middleware that calls `/api/members/session` and passes result to views

### Compliance Page Content
- Rewrite /privacy and /terms fresh using TWILIO_A2P_COMPLIANCE.md as source of truth
- Full app layout (shared Blade layout with navigation/footer) — not minimal standalone
- Pure Blade templates (no Vue/Inertia) — content visible in raw HTML for crawlers
- Shared Blade layout between compliance pages and the rest of the app
- /sms-opt-in shows a live demo mockup of the join page with unchecked consent checkbox (not functional, visual proof for Twilio)

### Deployment
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

</decisions>

<specifics>
## Specific Ideas

- "The whole point was to go all-in on Laravel, I don't want to use Node" — the migration should feel like a proper Laravel app, not a Node app with PHP bolted on
- API auth is cookie-based: `POST /api/members/confirm-verification` returns member data and sets session cookie, `GET /api/members/session` checks status
- TWILIO_A2P_COMPLIANCE.md has exact required language for privacy policy (third-party sharing statement) and terms (STOP/HELP in bold)
- The /sms-opt-in page is specifically for Twilio campaign reviewers to verify the opt-in flow exists

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TWILIO_A2P_COMPLIANCE.md`: Complete Twilio compliance requirements with exact required language — use as spec for /privacy, /terms, /sms-opt-in content
- `src/lib/api-client.ts`: Reference for all API endpoints currently called — use as guide for Laravel API service layer
- `src/pages/privacy/` and `src/pages/terms/`: Current page content to reference (though being rewritten)
- `src/pages/join/`: Join flow showing current SMS consent checkbox implementation — reference for /sms-opt-in mockup

### Established Patterns
- API base URL configured via environment variable (VITE_API_URL → will become Laravel .env variable)
- All API calls use credentials: 'include' for cookie forwarding — Laravel must replicate this behavior
- Session check via `GET /api/members/session` — used to gate authenticated routes

### Integration Points
- MakeReady API at `https://api.makeready.org` — all data source
- Railway deployment pipeline via GitHub Actions
- No database connection needed (API handles all persistence)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-compliance*
*Context gathered: 2026-03-16*
