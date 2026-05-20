# Phase 3: Join Flows + Member Pages - Research

**Researched:** 2026-03-17
**Domain:** Laravel Blade + Vue islands wired to MakeReady API — join flows and member pages
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Multi-step join flow state persisted in **Laravel session** between requests
- **Single Blade view with conditional step sections** — one template per join type (group, event, study), showing the right step based on session state
- **One route with step parameter**: `/join/group/{code}/{step?}` — step defaults to first (info)
- Phone entry and code verification use **Vue islands** (PhoneEntry, VerifyCode) mounted in the Blade template
- Vue interactive components submit via **AJAX + redirect** — send data to Laravel endpoint, get redirect URL back
- SMS consent checkbox placement: **match React app** (wherever it currently appears in the join flow)
- Server-side enforcement of SMS consent: Laravel controller rejects POST if consent not checked
- **All data loaded upfront** in the controller before rendering
- Controller calls ApiService, passes results to Blade view as variables
- Error handling: **match React app** behavior (inline error messages where content would be)
- Empty states: use the Blade `<x-primitive.empty-state>` component
- **Two Blade layout files**: `resources/views/layouts/auth.blade.php` (centered, for join/login) and `resources/views/layouts/home.blade.php` (nav + content, for authenticated pages)
- Pages `@extend` the appropriate layout
- Navigation account menu uses the **Vue modal system** (Pinia store opens bottom sheet — matches React behavior)
- URLs **adapted to Laravel conventions** (not exact React URLs, but close)
- Join flows use **one route + step parameter**: `/join/group/{code}/{step?}`, `/event/{code}/{step?}`, `/join/study/{identifier}/{step?}`
- Protected routes use `member.auth` middleware group
- Public routes (join, login, landing) have no auth middleware

### Claude's Discretion

- Exact route naming conventions
- Controller organization (one controller per page vs resource controllers)
- How to structure the session data for join flow state
- Error page design
- Which specific API endpoints to call per page (reference MCP server for details)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| JOIN-01 | Group join flow migrated (code → profile → phone → verify → confirm) | Full step map documented below; all Blade components and Vue islands exist |
| JOIN-02 | Study join flow migrated | Steps mapped from archive; StudyInfoCard + phone/verify Vue islands available |
| JOIN-03 | Event join flow migrated | Steps mapped from archive; EventCard Blade + phone/verify Vue islands available |
| JOIN-04 | Public join flow (alternative routing) migrated | JoinCodePage Blade component exists; route `/join` wires to it |
| JOIN-05 | Phone verification (SMS send + verify) working through Laravel API proxy | ApiService.post() pattern established; PhoneEntry and VerifyCode Vue islands wired |
| JOIN-06 | Multi-step state persisted in Pinia + server session (survives page refresh) | Laravel session stores step + collected form data; Vue islands communicate via AJAX |
| JOIN-07 | Join code entry page migrated | JoinCodePage Blade component + Input Blade component exist; code lookup via ApiService |
| MEMB-01 | Public home / landing page migrated | PublicHomePage maps to simple Blade view with session redirect check |
| MEMB-02 | Member login page migrated (phone-based auth) | PhoneEntry + VerifyCode Vue islands; AJAX submit → Laravel session cookie forwarding |
| MEMB-03 | Authenticated home page (groups list) migrated | API: /api/groups; GroupListCard Blade component exists |
| MEMB-04 | Group home page with studies and events migrated | API: /api/groups/{id}/public + /posts + /study-enrollment; all Blade components exist |
| MEMB-05 | Member profile viewing migrated | API: /api/members/session; ProfileForm Blade component exists |
| MEMB-06 | Member profile editing migrated | API: PATCH /api/members/{id}; ProfileForm Blade + file upload via AJAX |
| MEMB-07 | Groups list page migrated | API: /api/groups; GroupListCard Blade component exists |
</phase_requirements>

---

## Summary

Phase 3 wires the completed Blade component library (52 components) and Vue interactive islands (8 components) into real page templates that fetch live API data. The work divides into two major tracks: join flows (public, unauthenticated pages with multi-step state) and member pages (authenticated pages behind the `member.auth` middleware).

The key insight from studying the React source is that **join flows are the complex part** — each join type has 4-6 steps, phone verification AJAX, and SMS consent. Member pages are comparatively straightforward: the middleware already sets `$member` on the request, the controller calls ApiService once, and the Blade template renders with the data. The group-home page is the most complex member page due to paginated posts.

The existing infrastructure is well-prepared: ApiService, CheckMemberSession middleware, Vue island auto-mounter, and all required Blade/Vue components are in place from Phases 1 and 2. The two Blade layouts (`auth.blade.php` and `home.blade.php`) currently exist as component files but need to become proper `resources/views/layouts/` files that pages `@extend`.

**Primary recommendation:** Create two new layouts, then build each page as a thin Blade template calling existing Blade components, wiring Vue islands for PhoneEntry/VerifyCode via `data-vue` attributes and AJAX endpoints.

---

## Standard Stack

### Core (all already installed — Phase 1 and 2 complete)

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Laravel | 12.x | Routing, controllers, session, HTTP client | Framework |
| Blade templates | built-in | SSR page rendering | Decided in architecture |
| Vue 3 + Pinia | installed | Interactive islands (phone/verify) | Decided in architecture |
| ApiService | app/Services/ApiService.php | Cookie-proxying API calls | Established in Phase 1 |
| CheckMemberSession | app/Http/Middleware | Auth gate for protected routes | Established in Phase 1 |
| PHP session (file driver) | laravel default | Join flow multi-step state | Decided |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| Laravel `Http::fake()` | PHPUnit HTTP mocking | All feature tests that touch ApiService |
| Laravel `session()` | Join step state | Persisting form data between step GETs |
| `csrf_token()` / `@csrf` | AJAX CSRF | AJAX POST endpoints that modify state |
| Pinia modal store | Nav account menu | Already wired in modal-provider.vue |

---

## Architecture Patterns

### Layout Files (MUST CREATE — currently only exist as Blade components)

The current `resources/views/layouts/app.blade.php` is a single generic layout. Phase 3 replaces it with two purpose-built layouts:

**`resources/views/layouts/auth.blade.php`** — full-screen centered, gradient background, no nav bar. Used by: join flows, login, public home.

```blade
{{-- resources/views/layouts/auth.blade.php --}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'MakeReady')</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body class="AuthPage">
    @yield('content')
    <div data-vue="ModalProvider"></div>
</body>
</html>
```

**`resources/views/layouts/home.blade.php`** — navigation bar fixed at bottom, scrollable content. Used by: authenticated home, groups, group home, profile.

```blade
{{-- resources/views/layouts/home.blade.php --}}
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <title>@yield('title', 'MakeReady')</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body>
    @yield('content')
    <div data-vue="ModalProvider"></div>
</body>
</html>
```

Note: The Navigation Blade component is included inside individual page templates (not in the layout) because it needs per-page `selected` state and per-member avatar data.

### Controller Pattern (upfront data loading)

```php
// All API data fetched before render — no lazy loading
class GroupHomeController extends Controller
{
    public function __construct(private ApiService $api) {}

    public function show(Request $request, string $groupId): Response
    {
        $member = $request->attributes->get('member');

        $group = $this->api->get("/api/groups/{$groupId}/public", $request);
        $posts = $this->api->get("/api/groups/{$groupId}/posts?limit=10", $request);
        $enrollment = $this->api->get("/api/groups/{$groupId}/study-enrollment?memberId={$member['id']}", $request);

        // Treat non-200 as empty / error state — match React app behavior
        $groupData = $group['status'] === 200 ? $group['body']['group'] : null;
        $postsData = $posts['status'] === 200 ? ($posts['body']['posts'] ?? []) : [];
        $enrollmentData = $enrollment['status'] === 200 ? ($enrollment['body']['enrollment'] ?? null) : null;

        $response = response()->view('pages.group-home', compact(
            'member', 'groupId', 'groupData', 'postsData', 'enrollmentData'
        ));

        // Forward any refreshed session cookies
        foreach ($group['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }

        return $response;
    }
}
```

### Vue Island AJAX Pattern (join flow steps)

This is the established pattern for PhoneEntry and VerifyCode islands communicating back to Laravel:

**Blade template mounts the island with initial props and an AJAX endpoint:**
```blade
{{-- resources/views/pages/join-group.blade.php (phone step) --}}
<div
    data-vue="PhoneEntry"
    data-props="{{ json_encode([
        'title'               => 'Enter your phone',
        'ajaxEndpoint'        => route('join.group.phone.submit', ['code' => $code]),
        'secondaryButtonLabel'=> 'Change group',
        'secondaryRedirectUrl'=> route('join.enter-code'),
    ]) }}"
></div>
```

**PhoneEntry emits submit → AJAX POST → Laravel returns redirect URL:**
```javascript
// Vue island: on submit, POST to ajaxEndpoint, follow redirect
async function handleSubmit() {
    const response = await fetch(props.ajaxEndpoint, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').content,
            'Accept': 'application/json',
        },
        body: JSON.stringify({ phoneNumber: formattedPhone, smsConsent: consentChecked }),
    })
    const data = await response.json()
    if (data.redirectUrl) {
        window.location.href = data.redirectUrl
    }
}
```

**Laravel AJAX endpoint:**
```php
public function submitPhone(Request $request, string $code): JsonResponse
{
    // Validate SMS consent server-side
    if (!$request->boolean('smsConsent')) {
        return response()->json(['error' => 'SMS consent required'], 422);
    }

    $phone = $request->input('phoneNumber');

    // Store in session
    $request->session()->put("join.{$code}.phone", $phone);

    // Forward to API
    $result = $this->api->post('/api/members/verify-phone', [
        'phoneNumber'    => $phone,
        'organizationId' => $request->session()->get("join.{$code}.organizationId"),
    ], $request);

    if ($result['status'] !== 200) {
        return response()->json(['error' => $result['body']['message'] ?? 'Failed to send code'], 422);
    }

    return response()->json(['redirectUrl' => route('join.group.verify', ['code' => $code])]);
}
```

### Session State Structure (join flow)

Laravel session stores join progress keyed by group code to avoid collisions:

```php
// Session keys for group join
session()->put("join.{$code}.groupId", $groupPreview['id']);
session()->put("join.{$code}.organizationId", $groupPreview['organizationId']);
session()->put("join.{$code}.firstName", $request->input('first_name'));
session()->put("join.{$code}.lastName", $request->input('last_name'));
session()->put("join.{$code}.gender", $request->input('gender'));
session()->put("join.{$code}.birthday", $request->input('birthday'));
session()->put("join.{$code}.phone", $request->input('phone'));

// Session keys for event join (keyed by event code)
session()->put("event.{$code}.eventId", $event['id']);
session()->put("event.{$code}.phone", $request->input('phone'));

// Session keys for study join (keyed by identifier)
session()->put("study.{$identifier}.lessonId", $lesson['id']);
session()->put("study.{$identifier}.phone", $request->input('phone'));
```

After join confirmation, clear the session namespace: `session()->forget("join.{$code}")`.

### Single Blade View with Conditional Steps

```blade
{{-- resources/views/pages/join-group.blade.php --}}
@extends('layouts.auth')

@section('content')
    @if($step === 'info')
        <div class="JoinPage">
            <div class="JoinPage__container">
                <x-domain.group-leader-note ... />
                <x-panel.group-info-card ... >
                    <form method="POST" action="{{ route('join.group.info.submit', ['code' => $code]) }}">
                        @csrf
                        <x-primitive.button variant="White" mode="Block">Continue</x-primitive.button>
                    </form>
                </x-panel.group-info-card>
            </div>
        </div>

    @elseif($step === 'profile')
        {{-- Profile form — pure Blade POST --}}

    @elseif($step === 'phone')
        {{-- PhoneEntry Vue island via data-vue --}}

    @elseif($step === 'verify')
        {{-- VerifyCode Vue island via data-vue --}}

    @elseif($step === 'confirmed')
        {{-- Confirmation Blade component --}}

    @endif
@endsection
```

### Recommended Page/Controller Organization

One controller per page group (not resource controllers, since no CRUD):

```
app/Http/Controllers/
├── JoinController.php          ← /join (code entry) + all join flow steps
├── EventJoinController.php     ← /event/{code}/{step?}
├── StudyJoinController.php     ← /join/study/{identifier}/{step?}
├── MemberLoginController.php   ← /login (phone + verify steps)
├── HomeController.php          ← /home (already exists, extend it)
├── GroupsController.php        ← /groups list
├── GroupHomeController.php     ← /groups/{groupId}
├── ProfileController.php       ← /profile view + edit
└── PublicHomeController.php    ← / (public landing)
```

### Anti-Patterns to Avoid

- **Lazy API loading via Vue**: Do NOT fetch API data in Vue components. All data must be server-rendered for crawler visibility.
- **State in URL query params**: Use Laravel session for join step state — NOT query strings (sessionStorage is client-only and won't survive navigation to a new Laravel-rendered URL).
- **Separate route per step**: One route with optional `{step?}` param per join type — the controller reads `$step` and the view conditionally renders.
- **Rendering PHP redirect inside JSON response**: AJAX endpoints must return JSON `{redirectUrl: "..."}` — do NOT use `redirect()` for AJAX responses (it returns HTML).

---

## API Endpoints Map

All confirmed from React store source code (HIGH confidence):

### Join Flow Endpoints
| Endpoint | Method | Purpose | Steps |
|----------|--------|---------|-------|
| `GET /api/groups/code/{code}` | GET | Look up group by join code | info step |
| `POST /api/members/verify-phone` | POST | Send SMS code | phone step |
| `POST /api/members/confirm-verification` | POST | Verify code + create session | verify step |
| `POST /api/groups/{groupId}/join-requests` | POST | Submit join request | verify step (after auth) |
| `POST /api/members/logout` | POST | Log out current member | "Not me" flow |

**verify-phone request body:**
```json
{ "phoneNumber": "+1XXXXXXXXXX", "organizationId": "org_id_here" }
```

**confirm-verification request body:**
```json
{
  "phoneNumber": "+1XXXXXXXXXX",
  "code": "123456",
  "organizationId": "org_id_here",
  "firstName": "John",
  "lastName": "Doe",
  "gender": "male",
  "birthday": "1990-01-01"
}
```

### Event Join Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `GET /api/events/code/{code}` | GET | Look up event by code |
| `POST /api/members/verify-phone` | POST | Send SMS (same as group join) |
| `POST /api/members/confirm-verification` | POST | Verify + auth |
| `POST /api/events/{eventId}/attend` | POST | Register attendance |

### Member Page Endpoints
| Endpoint | Method | Purpose | Page |
|----------|--------|---------|------|
| `GET /api/members/session` | GET | Auth check + member data | middleware (already called) |
| `GET /api/groups` | GET | Member's groups list | /home, /groups |
| `GET /api/groups/{id}/public` | GET | Group details | /groups/{id} |
| `GET /api/groups/{id}/posts?limit=N` | GET | Group posts feed | /groups/{id} |
| `GET /api/groups/{id}/study-enrollment?memberId={id}` | GET | Current study progress | /groups/{id} |

### Login Page Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `POST /api/members/verify-phone` | POST | Send SMS to existing member |
| `POST /api/members/confirm-verification` | POST | Verify code → set session cookie |

### Profile Page Endpoints
| Endpoint | Method | Purpose |
|----------|--------|---------|
| `PATCH /api/members/{id}` | PATCH | Update profile fields |
| `POST /api/members/{id}/avatar` | POST | Upload avatar (multipart) |
| `POST /api/members/{id}/avatar/sync-google` | POST | Sync Google profile photo |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phone digit input | Custom keypad | `PhoneEntry` Vue island | Already implemented with keypad grid, backspace, display formatting |
| 6-digit code entry | Custom inputs | `VerifyCode` Vue island | Already handles paste, auto-advance, keyboard nav |
| Modal / bottom sheet | Custom overlay | Pinia modal store + ModalProvider | Already implemented; nav menu uses this |
| Group card display | Inline HTML | `<x-domain.group-card>` | 52 Blade components exist — use them all |
| Cookie forwarding | Custom cookie logic | ApiService | extractSetCookies() already handles multi-value Set-Cookie |
| Auth check | Custom middleware | `member.auth` middleware group | CheckMemberSession is written and tested |
| Profile form fields | Individual inputs | `<x-domain.profile-form>` | First/last/gender/birthday already wired with BEM styles |
| Join code display/input | Custom UI | `<x-domain.join-code-page>` | Blade component exists with logo, description, button |
| Confirmation screen | Custom layout | `<x-panel.confirmation>` | Supports color/icon/action slot |

**Key insight:** The entire component library is already built in Phase 2. Phase 3 should contain zero new component code — only controllers, routes, and thin Blade templates that compose existing components.

---

## Common Pitfalls

### Pitfall 1: AJAX response vs redirect response
**What goes wrong:** Returning `redirect()->route(...)` from an AJAX endpoint makes `fetch()` silently follow the redirect and return the HTML of the destination page — the `redirectUrl` JSON never arrives in the Vue component.
**Why it happens:** PHP/Laravel doesn't know the request is AJAX unless checked explicitly.
**How to avoid:** AJAX POST endpoints must return `response()->json(['redirectUrl' => '...'])`. Check with `$request->expectsJson()` or inspect the `Accept` header. Vue island sets `Accept: application/json`.
**Warning signs:** Vue island fetch resolves with HTML content instead of JSON object.

### Pitfall 2: Session lost between AJAX and page navigation
**What goes wrong:** Vue island stores data in a `fetch()` POST (PHP session set), then `window.location.href = redirectUrl` causes a new GET. If the session driver is cookie-based and the session cookie isn't being set correctly, the next GET starts a fresh session.
**Why it happens:** Laravel's default `cookie` session driver creates a new cookie with each response. The AJAX response must include `Set-Cookie` (Laravel handles this automatically for session writes).
**How to avoid:** Ensure session is started before writing. Verify the AJAX response includes `Set-Cookie: laravel_session=...` header. Do not use `stateless()` or disable sessions for AJAX routes.
**Warning signs:** Data put in session during AJAX POST is missing when the redirected GET page tries to read it.

### Pitfall 3: Multi-Pinia-instance problem (each Vue island is isolated)
**What goes wrong:** The Vue island auto-mounter creates a separate `createApp()` + `createPinia()` for each `data-vue` element. If two islands on the same page need to share state (e.g., PhoneEntry sets phone, VerifyCode reads it), they can't access each other's Pinia store.
**Why it happens:** Pinia stores are scoped to a Vue app instance. Separate `createApp()` calls = separate stores.
**How to avoid:** **Never** put phone number or other cross-island state in Pinia. Use the Laravel session (written via AJAX POST) as the source of truth. Pass state as server-rendered props when the page re-renders. Each step is a full page navigation, so state flows through the session.
**Warning signs:** Two Vue islands on the same page needing to communicate directly.

### Pitfall 4: Infinite scroll / pagination on group home
**What goes wrong:** The React group-home uses IntersectionObserver to load more posts. Server-side rendering means the first page of posts renders in Blade — but "load more" requires client-side JavaScript.
**Why it happens:** Infinite scroll is inherently client-side behavior.
**How to avoid:** Render first page of posts server-side. Add a "Load more" button (or a small Vue island for infinite scroll) that fetches `/api/groups/{id}/posts?cursor=X` client-side via a simple Vue component. This keeps SSR for the initial content (crawler-visible) while supporting pagination.
**Warning signs:** Trying to implement pagination purely in Blade with page reloads creates bad UX.

### Pitfall 5: File upload for avatar (profile editing)
**What goes wrong:** The profile edit page needs multipart/form-data file upload to `/api/members/{id}/avatar`. ApiService only has `get()` and `post()` (JSON). Multipart forwarding requires a different approach.
**Why it happens:** PHP's `Http::attach()` is different from `Http::post()` with JSON.
**How to avoid:** Use a thin AJAX approach: the profile edit form submits file selection client-side via a small Vue island or vanilla JS `fetch()` with `FormData`, forwarding the file to a Laravel endpoint that calls `Http::attach()`.
**Warning signs:** Trying to submit multipart through a standard Blade `<form>` to Laravel, then re-post as JSON.

### Pitfall 6: Double-navigation bar in home layout
**What goes wrong:** Including `<x-domain.navigation>` in both the home layout file AND individual page templates causes two navbars to render.
**Why it happens:** Temptation to "standardize" the nav in the layout like a traditional web app.
**How to avoid:** Navigation belongs in **page templates**, not the layout. Each authenticated page template includes `<x-domain.navigation :selected="'home'" ...>` with the correct `selected` value and member-specific data.
**Warning signs:** Navigation z-index bugs or double rendering.

### Pitfall 7: SMS consent not validated server-side
**What goes wrong:** SMS consent checkbox is rendered in the Vue PhoneEntry island as a slot. If Laravel only checks it client-side (Vue disables the button), a direct POST bypasses consent.
**Why it happens:** Client-side validation is easy to bypass.
**How to avoid:** AJAX POST endpoint for phone step must check `$request->boolean('smsConsent')` and return 422 if false. This is a compliance requirement (COMP-04).
**Warning signs:** The AJAX endpoint doesn't inspect the `smsConsent` field.

---

## Join Flow Step Maps

### Group Join Steps (JOIN-01)

| Step | Route | Controller Method | Vue Island | API Calls | Session Reads | Session Writes |
|------|-------|-------------------|-----------|-----------|---------------|----------------|
| info | `/join/group/{code}` (default) | `showInfo()` | none | `GET /api/groups/code/{code}` | — | groupId, organizationId |
| profile | `/join/group/{code}/profile` | `showProfile()` | none | none | groupId | firstName, lastName, gender, birthday |
| phone | `/join/group/{code}/phone` | `showPhone()` | PhoneEntry AJAX | `POST /api/members/verify-phone` | organizationId | phone |
| verify | `/join/group/{code}/verify` | `showVerify()` | VerifyCode AJAX | `POST /api/members/confirm-verification` then `POST .../join-requests` | all above | — (clear after) |
| confirmed | `/join/group/{code}/confirmed` | `showConfirmed()` | none | `GET /api/groups/code/{code}` | existingRequest status | — |

**Note on info step branch logic (from React source):**
- If API returns existing member is already in group → show "already a member" variant of GroupLeaderNote
- If member is authenticated but not in group → show "Accept Invite" button (skip profile/phone steps, call join-request directly)
- If not authenticated → show "Continue" → go to profile step

### Event Join Steps (JOIN-03)

| Step | Route | Vue Island | API Calls |
|------|-------|-----------|-----------|
| info | `/event/{code}` | none | `GET /api/events/code/{code}` |
| phone | `/event/{code}/phone` | PhoneEntry AJAX | `POST /api/members/verify-phone` |
| verify | `/event/{code}/verify` | VerifyCode AJAX | `POST /api/members/confirm-verification` then `POST /api/events/{id}/attend` |
| confirmed | `/event/{code}/confirmed` | none | none (session data) |

### Study Join Steps (JOIN-02)

| Step | Route | Vue Island | API Calls |
|------|-------|-----------|-----------|
| info | `/join/study/{identifier}` | none | `GET /api/lessons/code/{identifier}` (or by UUID) |
| phone | `/join/study/{identifier}/phone` | PhoneEntry AJAX | `POST /api/members/verify-phone` |
| verify | `/join/study/{identifier}/verify` | VerifyCode AJAX | `POST /api/members/confirm-verification` |
| confirmed | `/join/study/{identifier}/confirmed` | none | redirect to lesson |

### Login Flow Steps (MEMB-02)

| Step | Route | Vue Island | API Calls |
|------|-------|-----------|-----------|
| phone | `/login` | PhoneEntry AJAX | `POST /api/members/verify-phone` |
| verify | `/login/verify` | VerifyCode AJAX | `POST /api/members/confirm-verification` → sets API session cookie |

After successful verification, redirect to `/home`.

---

## Route Structure

```php
// routes/web.php additions for Phase 3

// ─── Public (no auth) ──────────────────────────────────────────────
Route::get('/', [PublicHomeController::class, 'index'])->name('home.public');

Route::get('/login', [MemberLoginController::class, 'showPhone'])->name('login');
Route::post('/login/phone', [MemberLoginController::class, 'submitPhone'])->name('login.phone.submit');
Route::get('/login/verify', [MemberLoginController::class, 'showVerify'])->name('login.verify');
Route::post('/login/verify', [MemberLoginController::class, 'submitVerify'])->name('login.verify.submit');
Route::post('/logout', [MemberLoginController::class, 'logout'])->name('logout');

// Group join flow
Route::get('/join', [JoinController::class, 'showEnterCode'])->name('join.enter-code');
Route::post('/join', [JoinController::class, 'submitCode'])->name('join.code.submit');
Route::get('/join/group/{code}/{step?}', [JoinController::class, 'showStep'])->name('join.group');
Route::post('/join/group/{code}/info', [JoinController::class, 'submitInfo'])->name('join.group.info.submit');
Route::post('/join/group/{code}/profile', [JoinController::class, 'submitProfile'])->name('join.group.profile.submit');
Route::post('/join/group/{code}/phone', [JoinController::class, 'submitPhone'])->name('join.group.phone.submit');
Route::post('/join/group/{code}/verify', [JoinController::class, 'submitVerify'])->name('join.group.verify.submit');

// Event join flow
Route::get('/event/{code}/{step?}', [EventJoinController::class, 'showStep'])->name('join.event');
Route::post('/event/{code}/phone', [EventJoinController::class, 'submitPhone'])->name('join.event.phone.submit');
Route::post('/event/{code}/verify', [EventJoinController::class, 'submitVerify'])->name('join.event.verify.submit');

// Study join flow
Route::get('/join/study/{identifier}/{step?}', [StudyJoinController::class, 'showStep'])->name('join.study');
Route::post('/join/study/{identifier}/phone', [StudyJoinController::class, 'submitPhone'])->name('join.study.phone.submit');
Route::post('/join/study/{identifier}/verify', [StudyJoinController::class, 'submitVerify'])->name('join.study.verify.submit');

// ─── Protected (member.auth) ───────────────────────────────────────
Route::middleware('member.auth')->group(function () {
    Route::get('/home', [HomeController::class, 'index'])->name('home');
    Route::get('/groups', [GroupsController::class, 'index'])->name('groups');
    Route::get('/groups/{groupId}', [GroupHomeController::class, 'show'])->name('group.home');
    Route::get('/profile', [ProfileController::class, 'show'])->name('profile');
    Route::post('/profile', [ProfileController::class, 'update'])->name('profile.update');
    Route::post('/profile/avatar', [ProfileController::class, 'uploadAvatar'])->name('profile.avatar');
});
```

---

## Existing Blade Components Ready to Use

All 52 components are verified present. Key components per page:

### Join Flows
- `<x-domain.join-code-page>` — code entry wrapper with logo + input slot
- `<x-panel.group-info-card>` — group photo, name, member count, button slot
- `<x-domain.group-leader-note mode="Invite|Member">` — personalized invite card
- `<x-domain.profile-form>` — first/last/gender/birthday fields
- `<x-panel.confirmation color="Green|Yellow|White">` — join success/pending/error screen
- `<x-domain.event-card>` — event title, date, time, location
- `<x-panel.study-info-card>` — study program details for study join
- `<x-primitive.step-indicator>` — multi-step progress dots
- `<x-primitive.empty-state>` — empty state display

### Member Pages
- `<x-domain.navigation :selected="'home'" :initials="'JD'" :avatarUrl="null">` — bottom nav bar
- `<x-domain.group-list-card>` — compact group card for lists
- `<x-domain.group-card mode="Header">` — full group hero card with back button
- `<x-domain.group-post-card>` — feed post card
- `<x-domain.study-card mode="Progress|LessonList">` — study enrollment card

### Vue Islands
- `data-vue="PhoneEntry"` — phone number keypad + submit
- `data-vue="VerifyCode"` — 6-digit code entry with paste support
- `data-vue="ModalProvider"` — renders the Pinia modal stack (must be in every layout)

---

## Code Examples

### Example: Mounting PhoneEntry with AJAX + SMS consent

```blade
{{-- Blade template: phone step --}}
<div
    data-vue="PhoneEntry"
    data-props="{{ json_encode([
        'title'                => 'Enter your phone',
        'ajaxSubmitUrl'        => route('join.group.phone.submit', ['code' => $code]),
        'secondaryButtonLabel' => 'Change group',
        'secondaryRedirectUrl' => route('join.enter-code'),
        'showSmsConsent'       => true,
        'privacyUrl'           => route('privacy'),
        'termsUrl'             => route('terms'),
    ]) }}"
></div>
```

PhoneEntry Vue island needs to be extended to accept `ajaxSubmitUrl` and emit the AJAX call. The current `phone-entry.vue` calls `props.onSubmit()` — this needs to become an internal AJAX call when `ajaxSubmitUrl` is provided.

### Example: Session state pattern for profile step POST

```php
// JoinController::submitProfile()
public function submitProfile(Request $request, string $code): JsonResponse|RedirectResponse
{
    $request->session()->put("join.{$code}.firstName", $request->input('first_name'));
    $request->session()->put("join.{$code}.lastName", $request->input('last_name'));
    $request->session()->put("join.{$code}.gender", $request->input('gender', ''));
    $request->session()->put("join.{$code}.birthday", $request->input('birthday', ''));

    return redirect()->route('join.group', ['code' => $code, 'step' => 'phone']);
}
```

Profile step is a plain Blade form POST (not AJAX) — no Vue island needed.

### Example: VerifyCode island with AJAX verify

```blade
<div
    data-vue="VerifyCode"
    data-props="{{ json_encode([
        'size'          => 'Large',
        'theme'         => 'Light',
        'autoFocus'     => true,
        'ajaxVerifyUrl' => route('join.group.verify.submit', ['code' => $code]),
        'redirectUrl'   => route('join.group', ['code' => $code, 'step' => 'confirmed']),
        'phone'         => $phone,
    ]) }}"
></div>
```

### Example: Authenticated home controller with single-group redirect

```php
// HomeController::index() — replicates React behavior:
// if member belongs to exactly one group, redirect directly to group home
public function index(Request $request): Response
{
    $member = $request->attributes->get('member');
    $groups = $this->api->get("/api/groups", $request);

    if ($groups['status'] === 200) {
        $groupList = $groups['body']['data'] ?? $groups['body']['groups'] ?? [];
        if (count($groupList) === 1) {
            return redirect()->route('group.home', ['groupId' => $groupList[0]['id']]);
        }
    } else {
        $groupList = [];
    }

    return response()->view('pages.home-authenticated', compact('member', 'groupList'));
}
```

---

## Vue Island Extension Requirements

The existing PhoneEntry and VerifyCode Vue islands were built as component-library components (props in, events out). For page integration, they need AJAX capability. Two options:

**Option A (recommended): Wrapper islands** — Create new Vue single-file components `JoinPhoneIsland.vue` and `JoinVerifyIsland.vue` that wrap the existing components and add AJAX logic. Keeps the original components pure.

**Option B: Extend existing** — Add optional `ajaxSubmitUrl` prop to `phone-entry.vue` and `verify-code.vue`. When prop is present, handle AJAX internally instead of emitting.

The planner should choose Option A to avoid modifying tested component-library components.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel 12 built-in) |
| Config file | `phpunit.xml` |
| Quick run command | `./vendor/bin/phpunit tests/Feature/JoinFlowTest.php` |
| Full suite command | `./vendor/bin/phpunit` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| JOIN-01 | Group join flow renders correct step content | Feature | `./vendor/bin/phpunit tests/Feature/JoinFlowTest.php` | ❌ Wave 0 |
| JOIN-02 | Study join flow renders correct step content | Feature | `./vendor/bin/phpunit tests/Feature/StudyJoinTest.php` | ❌ Wave 0 |
| JOIN-03 | Event join flow renders correct step content | Feature | `./vendor/bin/phpunit tests/Feature/EventJoinTest.php` | ❌ Wave 0 |
| JOIN-04 | /join renders JoinCodePage HTML | Feature | `./vendor/bin/phpunit tests/Feature/JoinFlowTest.php::test_enter_code_page_renders` | ❌ Wave 0 |
| JOIN-05 | Phone submit AJAX returns redirectUrl JSON | Feature | `./vendor/bin/phpunit tests/Feature/JoinFlowTest.php::test_phone_submit_returns_redirect` | ❌ Wave 0 |
| JOIN-06 | Session data persists between steps | Feature | `./vendor/bin/phpunit tests/Feature/JoinFlowTest.php::test_profile_stored_in_session` | ❌ Wave 0 |
| JOIN-07 | /join renders without auth | Feature | `./vendor/bin/phpunit tests/Feature/JoinFlowTest.php` | ❌ Wave 0 |
| MEMB-01 | / renders public home HTML (no redirect when unauthenticated) | Feature | `./vendor/bin/phpunit tests/Feature/MemberPagesTest.php::test_public_home_renders` | ❌ Wave 0 |
| MEMB-02 | /login renders phone entry; verify step sets cookie | Feature | `./vendor/bin/phpunit tests/Feature/MemberLoginTest.php` | ❌ Wave 0 |
| MEMB-03 | /home redirects unauthenticated; renders groups when auth | Feature | `./vendor/bin/phpunit tests/Feature/MemberPagesTest.php::test_authenticated_home` | ❌ Wave 0 |
| MEMB-04 | /groups/{id} renders group name server-side | Feature | `./vendor/bin/phpunit tests/Feature/MemberPagesTest.php::test_group_home_renders` | ❌ Wave 0 |
| MEMB-05 | /profile renders member data server-side | Feature | `./vendor/bin/phpunit tests/Feature/MemberPagesTest.php::test_profile_view` | ❌ Wave 0 |
| MEMB-06 | /profile POST updates member via API | Feature | `./vendor/bin/phpunit tests/Feature/MemberPagesTest.php::test_profile_update` | ❌ Wave 0 |
| MEMB-07 | /groups renders group list server-side | Feature | `./vendor/bin/phpunit tests/Feature/MemberPagesTest.php::test_groups_list` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `./vendor/bin/phpunit tests/Feature/JoinFlowTest.php tests/Feature/MemberPagesTest.php`
- **Per wave merge:** `./vendor/bin/phpunit`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/Feature/JoinFlowTest.php` — covers JOIN-01, JOIN-04, JOIN-05, JOIN-06, JOIN-07
- [ ] `tests/Feature/EventJoinTest.php` — covers JOIN-03
- [ ] `tests/Feature/StudyJoinTest.php` — covers JOIN-02
- [ ] `tests/Feature/MemberLoginTest.php` — covers MEMB-02
- [ ] `tests/Feature/MemberPagesTest.php` — covers MEMB-01, MEMB-03, MEMB-04, MEMB-05, MEMB-06, MEMB-07

Test pattern from existing tests: use `Http::fake()` to mock API responses, then `$this->get('/route')` and assert on HTML content. For session-dependent tests, use `withSession(['join.CODE.groupId' => '...'])`.

---

## Open Questions

1. **Study identifier: code vs UUID**
   - What we know: React's study-join handles both `/join/study/:identifier` where identifier can be a lesson code (short string) or UUID
   - What's unclear: Does the API have a single endpoint that handles both, or separate endpoints?
   - Recommendation: Check `GET /api/lessons/code/{identifier}` — if 404, try `GET /api/lessons/{identifier}` (UUID). Or query MCP API server for the exact endpoint.

2. **PhoneEntry slot for SMS consent**
   - What we know: React's `JoinPhone` renders a `<label>SmsConsent</label>` as a child of `<PhoneEntry>` via JSX children. The Vue `phone-entry.vue` has a `<slot />` between error and submit button.
   - What's unclear: Whether passing SMS consent HTML through `data-props` JSON is feasible (it contains HTML markup with links).
   - Recommendation: Use the `<slot />` in PhoneEntry by creating a wrapper island that renders the consent HTML inside the mounted component, OR pass `showSmsConsent: true` as a prop and render the consent markup inside `phone-entry.vue` itself (matching the React implementation where consent is hardcoded inside PhoneEntry's children).

3. **Logout endpoint method**
   - What we know: React calls `POST /api/members/logout`. The NavigationMenuContent Blade component already has a `<form method="POST" action="{{ $logoutHref }}">` with `@csrf`.
   - What's unclear: The actual Laravel logout route needs to call ApiService to clear the API session cookie.
   - Recommendation: Add `Route::post('/logout', ...)` that calls `ApiService->post('/api/members/logout', [], $request)` then forwards any Set-Cookie headers to invalidate the API session, then redirects to `/`.

4. **Avatar upload forwarding**
   - What we know: API expects multipart POST to `/api/members/{id}/avatar`. ApiService only does JSON.
   - What's unclear: Does ApiService need a new `upload()` method, or should the profile edit use a client-side AJAX upload?
   - Recommendation: Add `ApiService::upload(string $endpoint, string $fileKey, UploadedFile $file, Request $request): array` using `Http::attach()`. This keeps the pattern consistent.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| React SPA with React Router (step = URL segment) | Laravel session (step persisted server-side, Blade conditional) | Full SSR per step; crawlers see content |
| MobX stores (JoinStore, EventJoinStore) | Laravel session + controller methods | No client state across steps; refresh-safe |
| React apiClient with automatic cookie handling | ApiService with explicit cookie forwarding | Same end result, explicit is better |
| `sessionStorage` persistence (React) | Laravel `session()` persistence | Survives tab close; no JS dependency |

---

## Sources

### Primary (HIGH confidence)
- `archive/react-spa:src/pages/` — all React page implementations (viewed via git show)
- `archive/react-spa:src/store/JoinStore.ts` — all group join API calls confirmed
- `archive/react-spa:src/store/EventJoinStore.ts` — all event join API calls confirmed
- `resources/views/components/` — all 52 Blade components verified present
- `resources/js/components/` — all 8 Vue islands verified present
- `app/Services/ApiService.php` — cookie proxy pattern confirmed
- `app/Http/Middleware/CheckMemberSession.php` — auth middleware pattern confirmed
- `resources/js/app.js` — Vue island auto-mounter pattern confirmed
- `resources/js/stores/modal.store.ts` — Pinia modal store confirmed

### Secondary (MEDIUM confidence)
- `archive/react-spa:src/store/ui/group-home.ui.ts` — group home API endpoints (inferred from store calls)
- `archive/react-spa:src/store/ui/groups-list.ui.ts` — groups list API endpoint
- `archive/react-spa:src/pages/study-join/study-join.page.tsx` — study join step structure

### Tertiary (LOW confidence — verify with MCP API server)
- Study join exact endpoint path: `/api/lessons/code/{identifier}` — assumed from naming patterns, not confirmed
- Avatar upload endpoint: `/api/members/{id}/avatar` — inferred from React profile page source
- Groups endpoint response shape: `{ success: bool, data: Group[] }` vs `{ success: bool, groups: Group[] }` — React source shows inconsistency between home page (uses `data`) and groups page (uses `groups`)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries installed and tested in Phase 1-2
- Architecture: HIGH — Vue island mounting pattern confirmed working, ApiService confirmed working
- API endpoints: HIGH for join flow (read from JoinStore/EventJoinStore source), MEDIUM for member pages (read from UI stores), LOW for study join exact endpoint
- Pitfalls: HIGH — AJAX vs redirect pitfall is well-documented; session isolation pitfall confirmed from Vue island auto-mounter code
- Join step maps: HIGH — mapped directly from React component source code

**Research date:** 2026-03-17
**Valid until:** 2026-06-17 (API is stable; Laravel 12 is stable)
