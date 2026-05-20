# External Integrations

**Analysis Date:** 2026-03-16

## APIs & External Services

**Backend API:**
- MakeReady API Server - Custom backend for all business logic
  - SDK/Client: Custom `apiClient` singleton in `src/lib/api-client.ts`
  - Base URL: Configurable via `VITE_API_URL` environment variable
  - Default (dev): `http://localhost:3001`
  - Default (prod): `https://api.makeready.org`
  - Auth: Session-based via HTTP cookies (credentials: 'include')
  - Features:
    - Groups API - Group listing, creation, membership
    - Members API - Member profiles, verification, registration
    - Activities API - Activity feeds and content
    - Organizations API - Organization management
    - Phone verification - SMS verification for members
    - Profile management - User profile CRUD operations

**Video Streaming:**
- HLS (HTTP Live Streaming) - Video playback via hls.js 1.6.15
  - Uses standard .m3u8 playlists from backend
  - No external video hosting service detected

## Data Storage

**Databases:**
- Backend managed - Client has no direct database access
  - Connection: Via API endpoints through `apiClient`
  - Client: REST API via `fetch` with automatic JSON serialization

**File Storage:**
- Backend managed - Client has no direct file storage access
  - Upload: Multipart FormData via `apiClient.upload()` in `src/lib/api-client.ts`
  - Download: Via API endpoints (e.g., cover images, profile pictures)

**Caching:**
- Browser cache - Standard HTTP caching headers from API responses
- No explicit caching library detected
- MobX state management in memory for session data

**State Persistence:**
- Session cookies - HTTP-only cookies managed by browser
- No localStorage or sessionStorage usage detected in API layer
- Application state managed entirely in MobX stores

## Authentication & Identity

**Auth Provider:**
- Custom (built in-house)
  - Implementation: Session-based authentication via HTTP cookies
  - Login flow: Phone verification + member registration
  - Sessions: Managed by backend, enforced via session cookies
  - Phone verification: SMS-based verification (see member-login flow)

**Authorization:**
- Role-based access control enforced on backend
  - Member access: Standard member experience
  - Admin/Leader access: Separate admin dashboard (iPhone app)
  - Group membership: Required for group-specific endpoints

## Monitoring & Observability

**Error Tracking:**
- Not detected - No Sentry, LogRocket, or similar service integrated

**Logs:**
- Console logging - Development-only logging via `console.warn()` and `console.error()`
- No centralized logging service detected
- Debug helper available: `window.session()` in console for join flow inspection

## CI/CD & Deployment

**Hosting:**
- Express server (`server.js`) - Static file serving for built React app
- Railway platform (inferred from team memory) - Deployment via CI/CD pipeline

**CI Pipeline:**
- GitHub Actions - Automated deployment on push
- Playwright E2E testing - Configured in `playwright.config.ts`
- Docker support - `docker-compose.test.yml` for test environment

**Build Artifacts:**
- Vite build output - Static files in `dist/` directory
- Storybook static build - `storybook-static/` directory
- Playwright reports - `playwright-report/` directory

## Environment Configuration

**Required env vars (development):**
- `VITE_API_URL` - Backend API URL (optional, defaults to `http://localhost:3001`)

**Required env vars (production):**
- `VITE_API_URL` - Must point to production API at `https://api.makeready.org` (optional, used as fallback)

**Optional env vars:**
- `E2E_BASE_URL` - Override E2E test base URL (defaults to `http://localhost:4173`)
- `CI` - Set by CI/CD pipeline (used in Playwright config)

**Secrets location:**
- `.env` and `.env.production` files - Listed in `.gitignore`
- CI/CD secrets - Managed by GitHub Actions (Railway integration)
- No hardcoded API keys or tokens in source code

**No secrets detected in client:**
- All authentication via secure HTTP-only cookies
- No API keys, tokens, or credentials stored client-side

## Webhooks & Callbacks

**Incoming:**
- None detected - Client receives data via standard REST API polling

**Outgoing:**
- None detected - No webhook subscriptions or callbacks to external services

## Testing Infrastructure

**API Mocking (Development):**
- Mock Service Worker (msw) 2.12.7 - Request/response mocking for tests
  - Server setup: `test/mocks/server.ts`
  - Handlers: Defined in test files using `http.get()`, `http.post()`, etc.
  - Test environment: `happy-dom` for lightweight DOM

**E2E Testing:**
- Playwright against Docker services
  - Docker Compose config: `docker-compose.test.yml`
  - Base URL: `http://localhost:4173` (Vite preview)
  - Browsers: Chromium (Firefox/Safari commented out)
  - CI retries: 2 attempts
  - Screenshots/videos: Only on failure

## Third-Party UI Libraries

**Component Primitives:**
- Radix UI - Accessible unstyled components
  - @radix-ui/react-dialog 1.1.15 - Modal dialogs
  - @radix-ui/react-dropdown-menu 2.1.2 - Dropdown menus
  - @radix-ui/react-select 2.2.6 - Select dropdowns
  - @radix-ui/react-tabs 1.1.13 - Tab components
  - @radix-ui/react-avatar 1.1.10 - User avatars
  - @radix-ui/react-label 2.1.0 - Form labels
  - @radix-ui/react-separator 1.1.8 - Visual separators
  - @radix-ui/react-slot 1.2.4 - Slot rendering
  - @radix-ui/react-tooltip 1.1.4 - Tooltips
  - @radix-ui/react-toast 1.2.2 - Toast notifications

**Icon Libraries:**
- lucide-react 0.454.0 - Consistent icon set
- react-icons 5.5.0 - Additional icon options (Material Design, Font Awesome, etc.)

**Rich Text Editing:**
- Lexical 0.39.0 - Modern rich text editor framework
- @lexical/react 0.39.0 - React integration
- @lexical/list 0.39.0 - List plugin

## Security Notes

**CORS:**
- Credentials mode: `include` - Cookies sent with cross-origin requests
- Content-Type: Always `application/json` for API calls

**API Error Handling:**
- Generic error messages shown to users
- Detailed error logging suppressed in production
- HTTP status codes properly propagated

**Session Management:**
- HTTP-only cookies (browser-managed, not accessible to JavaScript)
- CSRF protection: Likely handled by backend (not visible in client code)
- No tokens stored in localStorage or sessionStorage

---

*Integration audit: 2026-03-16*
