# Phase 5: Admin Shell — Research

**Researched:** 2026-03-19
**Domain:** Laravel Blade layout, Vue Router inside a single island, Pinia single-instance state, CSRF/axios configuration, leader detection via Google link, experience toggle navigation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Fixed left sidebar, icon-only by default, expandable on hover/click to show labels
- Sections: Dashboard, Groups, Programs, Profile
- Active item indicated by highlight background (subtle background color change)
- Avatar at bottom of sidebar, opens menu on click
- Sidebar + content area layout (no header bar)
- Same dark theme as member experience (dark backgrounds, white text, purple accents)
- Content area has max-width and is centered (similar to member experience's constrained containers)
- Each section has a page title header with action buttons on the right
- "Member Experience" / "Group Leader Admin" link appears at TOP of avatar menu
- Full page navigation when switching (clicking navigates to /admin or /member/home)
- "Group Leader Admin" link only shows for leaders — determined by having a linked Google account (call `/auth/me/linked-user` to check)
- "Member Experience" link always shows on admin avatar menu
- Path-based URLs: /admin, /admin/groups, /admin/groups/:id, /admin/programs, /admin/programs/:id, /admin/profile
- Client-side navigation via Vue Router (history mode) — sidebar clicks don't cause full page reloads
- Deep links work — Laravel catch-all route for /admin/* serves the admin shell Blade template, Vue Router picks up the path
- Single AdminIsland Vue app with shared Pinia state across all sections
- Skeleton loaders while content loads from API (placeholder shapes matching content layout)

### Claude's Discretion
- Exact sidebar width (collapsed and expanded)
- Skeleton loader shapes and animation
- Transition animations for sidebar expand/collapse
- Exact content area max-width value
- CSRF configuration approach (meta tag or cookie)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SHELL-01 | Leader can access admin panel at /admin when authenticated | Existing `/admin` route + `member.auth` middleware covers this. Requires expanding to catch-all `/admin/{any?}`. |
| SHELL-02 | Admin layout renders sidebar navigation with links to all entity sections (Dashboard, Groups, Programs) | New `layouts/admin.blade.php` with Blade sidebar nav. AdminIsland mounted inside with Vue Router for client-side sub-navigation. |
| SHELL-03 | Avatar menu on admin shows "Member Experience" link that navigates to /member/home | Admin sidebar avatar button opens inline dropdown (not a modal). "Member Experience" at top linking to `/member/home`. |
| SHELL-04 | Avatar menu on member experience shows "Group Leader Admin" link that navigates to /admin | Modify `navigation-island.vue` to call `/auth/me/linked-user`; show "Group Leader Admin" if linked user exists. |
| SHELL-05 | Unauthenticated users accessing /admin are redirected to login | `member.auth` middleware on all `/admin/*` routes; currently redirects to `/`. Must redirect to `/login` instead, or is consistent with existing pattern (redirects to `/`). |
| SHELL-06 | Admin panel mounts as a single Vue island with shared Pinia state across all sections | Single `data-vue="AdminIsland"` on catch-all Blade template. One `createApp` + one `createPinia()`. All sections rendered inside Vue Router `<router-view>`. |
| SHELL-07 | Section navigation within admin is client-side (no full page reloads between admin pages) | Vue Router history mode inside AdminIsland. Laravel catch-all route serves same Blade template for all `/admin/*` paths. `router.push()` / `<router-link>` used for sidebar navigation. |
</phase_requirements>

---

## Summary

Phase 5 establishes the admin panel infrastructure that every subsequent phase builds on. This is not a CRUD feature phase — it delivers the shell: authenticated access, the Blade layout with sidebar, the single AdminIsland Vue app with Vue Router for client-side navigation, CSRF configuration for all future admin API calls, and the experience toggle between member and admin views.

The current codebase already has a working `/admin` route (single GET, guarded by `member.auth` middleware), an `AdminController` that renders a placeholder Blade page, and a `pages/admin.scss` stub. Phase 5 expands this stub into a fully operational shell. No existing member-facing routes or components are deleted — the admin layout lives under a new `layouts/admin.blade.php` and the existing `home.blade.php` / member pages are untouched except for a targeted addition to `navigation-island.vue` (SHELL-04).

The single architectural decision that must be locked in this phase — before any CRUD work begins — is that **Vue Router runs inside AdminIsland** and **Laravel serves a single catch-all Blade page for all `/admin/*` paths**. This prevents the page-reload state-loss pitfall and the multi-island Pinia isolation pitfall documented in PITFALLS.md. Both pitfalls have HIGH recovery cost if discovered late. This phase resolves them at zero risk because no CRUD features exist yet.

**Primary recommendation:** Install `vue-router@4`, configure history mode inside AdminIsland, add the Laravel catch-all `/admin/{any?}` route, and wire CSRF axios configuration in AdminIsland's `onMounted` — all before writing a single admin store or component.

---

## Standard Stack

### Core (already installed — no new installs needed for Phase 5 shell)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| vue | ^3.5.30 | AdminIsland component tree | Already in devDependencies |
| pinia | ^3.0.4 | Admin state management | Already in dependencies; single instance inside AdminIsland |
| axios | ^1.11.0 | Admin API calls to `/admin/api/*` | Already in devDependencies via Laravel scaffold |
| reka-ui | ^2.9.2 | Skeleton loaders (Skeleton primitive) | Already installed; Skeleton component confirmed in reka-ui 2.x |

### New Dependencies for Phase 5

| Library | Version | Purpose | Why Needed |
|---------|---------|---------|------------|
| vue-router | 4.x (latest: 4.5.x) | History-mode client navigation inside AdminIsland | Not installed. Required for SHELL-07: client-side navigation without page reloads. The catch-all Laravel route + Vue Router history mode is the only architecture that satisfies deep-link support AND no-reload navigation simultaneously. |

**Note on vue-router version:** vue-router 5.0.4 is available on npm as of March 2026. Vue Router 4.x is the stable, LTS-supported version for Vue 3 and is the correct choice for this project. Vue Router 5 is in early release; do not use it.

**Installation:**
```bash
npm install vue-router@^4.5.0
```

### No Additional Libraries Needed for Phase 5

The skeleton loaders, sidebar CSS, and avatar menu are implemented with:
- reka-ui `Skeleton` component (already installed) for loading placeholders
- Pure BEM/SCSS for sidebar layout — no CSS framework
- Inline Vue `<Teleport>` + `ref` for the avatar dropdown (same pattern as `navigation-island.vue`)

---

## Architecture Patterns

### Recommended Project Structure for Phase 5

```
resources/
├── js/
│   ├── islands/
│   │   └── admin-island/
│   │       ├── admin-island.vue          # Root: Vue Router + AdminLayout wrapper
│   │       ├── router.ts                 # Vue Router history mode, /admin routes
│   │       ├── sections/
│   │       │   ├── dashboard-section.vue # Placeholder — content in Phase 9
│   │       │   ├── groups-section.vue    # Placeholder — content in Phase 6
│   │       │   ├── programs-section.vue  # Placeholder — content in Phase 7
│   │       │   └── profile-section.vue   # Placeholder — content in Phase 9
│   │       └── stores/
│   │           └── leader.store.ts       # Leader detection: linked Google account
│   ├── components/
│   │   └── domain/
│   │       └── navigation-island/
│   │           └── navigation-island.vue # MODIFIED: add "Group Leader Admin" link
│   └── app.js                            # MODIFIED: register AdminIsland
├── views/
│   ├── layouts/
│   │   └── admin.blade.php               # NEW: admin shell layout (sidebar + slot)
│   └── pages/
│       └── admin.blade.php               # MODIFIED: extend admin.blade.php, mount AdminIsland
└── css/
    ├── layouts/
    │   └── admin-layout.scss             # NEW: sidebar + content area layout
    ├── components/
    │   └── admin/
    │       ├── admin-sidebar.scss        # NEW: icon-only sidebar, hover expand
    │       ├── admin-avatar-menu.scss    # NEW: avatar dropdown in sidebar
    │       └── admin-skeleton.scss       # NEW: skeleton loader placeholder styles
    └── pages/
        └── admin.scss                    # EXISTING: extend for admin page styles
```

Laravel:
```
routes/web.php                            # MODIFIED: expand /admin group to catch-all
app/Http/Controllers/AdminController.php  # MODIFIED: single method serves all /admin/* paths
app/Services/ApiService.php               # MODIFIED: add delete() method
```

### Pattern 1: Vue Router Inside a Single Island (catch-all + history mode)

**What:** Laravel serves one Blade template for ALL `/admin/*` URLs. The template mounts a single `AdminIsland` Vue app. Inside the island, `vue-router` in history mode reads `window.location.pathname` and renders the correct section component. Sidebar `<router-link>` tags update the URL without page reloads.

**When to use:** Always for admin navigation. This is the locked architecture decision for this phase.

**Why it works:** Laravel's catch-all route passes any `/admin/path` to the same Blade template. Vue Router picks up the path from `window.location` on mount and renders the right view. Deep-linking (`/admin/groups`) works because Laravel serves the same Blade shell regardless of the sub-path. Browser back/forward works because Vue Router uses `history.pushState`.

**Example:**

```php
// routes/web.php — CATCH-ALL: must come AFTER any /admin/api/* proxy route
Route::middleware('member.auth')
    ->prefix('admin')
    ->group(function () {
        // API proxy routes registered here first (Phase 6+)

        // Catch-all: serves admin Blade template for all /admin/* paths
        Route::get('/{any?}', [AdminController::class, 'show'])
            ->where('any', '.*')
            ->name('admin');
    });
```

```typescript
// resources/js/islands/admin-island/router.ts
import { createRouter, createWebHistory } from 'vue-router'
import DashboardSection from './sections/dashboard-section.vue'
import GroupsSection from './sections/groups-section.vue'
import ProgramsSection from './sections/programs-section.vue'
import ProfileSection from './sections/profile-section.vue'

export const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/admin', component: DashboardSection },
    { path: '/admin/groups', component: GroupsSection },
    { path: '/admin/groups/:id', component: GroupsSection },
    { path: '/admin/programs', component: ProgramsSection },
    { path: '/admin/programs/:id', component: ProgramsSection },
    { path: '/admin/profile', component: ProfileSection },
    { path: '/admin/:pathMatch(.*)*', redirect: '/admin' },
  ],
})
```

```typescript
// resources/js/islands/admin-island/admin-island.vue
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import { router } from './router'
import AdminIsland from './admin-island.vue'

// Registered in app.js componentRegistry as 'AdminIsland'
// app.js's island mounter calls createApp(Component, props) then app.use(createPinia())
// We need to also use(router) — requires a modified mount approach (see Pattern 2)
```

### Pattern 2: AdminIsland Registration in app.js

**What:** The existing `app.js` island mounter calls `createApp(Component, props)` then `app.use(createPinia())`. AdminIsland needs `app.use(router)` too. The cleanest approach is to let `AdminIsland.vue` self-configure via its `app` — but the existing mounter doesn't support this. The correct approach is to add a special-case branch in `app.js` for AdminIsland, or to register AdminIsland with a factory function instead of a component reference.

**Recommended approach:** Add a thin override for AdminIsland in `app.js` using the `setup` hook pattern. AdminIsland's `onMounted` configures CSRF; `app.use(router)` is called before mount.

```javascript
// resources/js/app.js — modified section
import AdminIsland from './islands/admin-island/admin-island.vue'
import { router as adminRouter } from './islands/admin-island/router'

const componentRegistry = {
  // ... existing components ...
  'AdminIsland': AdminIsland,
}

document.querySelectorAll('[data-vue]').forEach((el) => {
  const name = el.dataset.vue
  const Component = componentRegistry[name]
  if (!Component) {
    console.warn(`[Vue islands] No component registered for "${name}"`)
    return
  }
  const props = el.dataset.props ? JSON.parse(el.dataset.props) : {}
  const app = createApp(Component, props)
  app.use(createPinia())

  // Admin island needs Vue Router
  if (name === 'AdminIsland') {
    app.use(adminRouter)
  }

  app.mount(el)
})
```

**Source:** Derived from the existing app.js pattern (codebase inspection, HIGH confidence). Vue Router installation via `app.use(router)` is documented behavior.

### Pattern 3: CSRF Axios Configuration in AdminIsland onMounted

**What:** Configure `axios.defaults.headers.common['X-CSRF-TOKEN']` from the `<meta name="csrf-token">` tag once, at island mount time. All subsequent axios calls from any Pinia store action inside the admin island automatically include the CSRF token.

**When to use:** AdminIsland `onMounted`. Done once, applies globally to all admin API calls. Never pass CSRF token through island props or store actions.

**Example:**
```typescript
// resources/js/islands/admin-island/admin-island.vue
import { onMounted } from 'vue'
import axios from 'axios'

onMounted(() => {
  const meta = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
  if (meta?.content) {
    axios.defaults.headers.common['X-CSRF-TOKEN'] = meta.content
  }
})
```

**Verification:** `home.blade.php` (the layout that currently serves `/admin`) already includes `<meta name="csrf-token" content="{{ csrf_token() }}">`. The new `admin.blade.php` layout must also include this tag. Confirmed from codebase inspection (HIGH confidence).

### Pattern 4: Leader Detection via `/auth/me/linked-user`

**What:** The "Group Leader Admin" link in the member navigation avatar menu is only shown to members who have a linked Google account. The check is made by calling `/auth/me/linked-user` from the `navigation-island.vue` component on mount. If the response contains a linked user, the link is shown.

**Current state:** `navigation-island.vue` already receives `googleEmail` as a prop from Blade. This prop is populated from `$member['googleEmail']` which is returned by the `/api/members/session` response via `CheckMemberSession` middleware. The `googleEmail` field exists in the session response — confirmed by existing usage in `home-authenticated.blade.php`, `groups.blade.php`, `group-home.blade.php`, and `study-home.blade.php`.

**Simplest approach for SHELL-04:** Use the already-available `googleEmail` prop in `navigation-island.vue` to conditionally render the "Group Leader Admin" link. No additional API call needed — the session middleware already loads this data and passes it to Blade props.

```vue
<!-- navigation-island.vue — add to avatar menu, at the TOP, before other items -->
<a
  v-if="googleEmail"
  href="/admin"
  class="Button Button--primary Button--size-default Button--mode-block"
>
  <span class="Button__content">
    <span class="Button__label">Group Leader Admin</span>
  </span>
</a>
```

**Confidence:** HIGH. `googleEmail` is confirmed in the NavigationIsland props interface and populated from session data in all Blade pages that use NavigationIsland.

### Pattern 5: Admin Blade Layout (Sidebar Shell)

**What:** `layouts/admin.blade.php` is a server-rendered HTML shell that provides: the `<head>` with CSRF meta tag, the fixed sidebar nav (pure Blade/HTML — no Vue), and a main content area where AdminIsland mounts. The sidebar nav links are standard `<a href>` tags that Vue Router intercepts client-side (because Vue Router in history mode intercepts same-origin navigation automatically when using `<router-link>`, but not raw `<a>` tags unless you use `router.push` manually).

**Important:** To get client-side navigation from Blade sidebar links, use `router-link` rendered inside the AdminIsland itself, not raw Blade `<a>` tags. The Blade layout provides the shell chrome (page title, body structure), but the sidebar nav items that need Vue Router awareness should be rendered by the AdminIsland, not Blade.

**Two-layer approach:**
1. **Blade layer** — page shell: `<head>`, `<meta csrf-token>`, body wrapper, any truly static chrome
2. **Vue layer (AdminIsland)** — everything interactive: sidebar links (router-link), avatar dropdown, content area (`<router-view>`)

```blade
{{-- resources/views/layouts/admin.blade.php --}}
<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <link rel="icon" type="image/svg+xml" href="/logo-mark.svg">
    <title>@yield('title', 'MakeReady Admin')</title>
    @vite(['resources/css/app.scss', 'resources/js/app.js'])
</head>
<body class="AdminBody">
    <div
        id="admin-island"
        data-vue="AdminIsland"
        data-props="{{ json_encode($islandProps ?? []) }}"
    ></div>
</body>
</html>
```

### Pattern 6: AdminController — Serve All /admin/* Paths

**What:** The current `AdminController::show()` method is a stub. It needs to pass member data to the Blade template, and the route needs to expand to a catch-all.

```php
// app/Http/Controllers/AdminController.php
public function show(Request $request): \Illuminate\View\View
{
    $member = $request->attributes->get('member');

    $islandProps = [
        'avatarUrl'    => $member['profilePicture'] ?? $member['avatarUrl'] ?? null,
        'initials'     => $this->buildInitials($member),
        'memberName'   => trim(($member['firstName'] ?? '') . ' ' . ($member['lastName'] ?? '')),
        'googleEmail'  => $member['googleEmail'] ?? null,
        'logoutUrl'    => route('logout'),
    ];

    return view('pages.admin', compact('member', 'islandProps'));
}
```

### Pattern 7: ApiService::delete() Method

**What:** `ApiService.php` has `get()`, `post()`, `patch()`, and `upload()` but is missing `delete()`. All admin CRUD phases from Phase 6 onwards require DELETE. Add it in Phase 5 so the proxy infrastructure is complete before any CRUD work begins.

```php
// app/Services/ApiService.php — add after patch()
public function delete(string $endpoint, Request $request): array
{
    $response = Http::withHeaders([
        'Cookie'  => $this->extractApiCookies($request),
        'Accept'  => 'application/json',
    ])->delete("{$this->baseUrl}{$endpoint}");

    return [
        'status'     => $response->status(),
        'body'       => $response->json(),
        'setCookies' => $this->extractSetCookies($response),
    ];
}
```

**Source:** Pattern directly mirrors existing `patch()` method (codebase inspection, HIGH confidence).

### Anti-Patterns to Avoid

- **Split admin across two `data-vue` elements**: Never put the sidebar in one island and content in another. They cannot share Pinia state. Always a single `data-vue="AdminIsland"` per page.
- **Raw `<a href>` for admin sidebar navigation**: Links inside the Vue island must use `<router-link>` or `router.push()`. Raw `<a href>` tags cause full page reloads, destroying Vue state and defeating SHELL-07.
- **Vue Router 5**: The `npm view vue-router version` returns 5.0.4 as the latest dist-tag. Use `vue-router@^4.5.0` explicitly — Vue Router 4 is the stable, broadly-tested release for Vue 3 applications.
- **Passing CSRF token as island prop**: Do not add `csrfToken` to AdminIsland's props. Use the `meta[name="csrf-token"]` approach in `onMounted`. This is already partially established in `navigation-island.vue` (it falls back to `document.querySelector('meta[name="csrf-token"]')` when no prop is provided).
- **Redirect to `/`** for unauthenticated admin access: `CheckMemberSession` currently redirects to `/`. For admin, SHELL-05 says "redirected to login." The current middleware redirects to `/` (the public home). This is fine for now — the planner should decide whether to change the redirect target or leave it as-is. Not a blocker for the shell phase.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Client-side routing with URL history | `history.pushState` + custom route matching | `vue-router@^4.5.0` | Route matching, scroll restoration, navigation guards, nested routes — all edge cases handled |
| Skeleton loader UI | Custom CSS animated placeholder blocks | reka-ui `Skeleton` primitive | Already installed; consistent with project's reka-ui usage |
| Icon set for admin sidebar | Custom SVG inlining in Blade | `lucide-vue-next` (already installed) | `lucide-vue-next@^0.577.0` is in devDependencies; provides all icons needed (LayoutDashboard, Users, BookOpen, User, ChevronLeft, ChevronRight) |

---

## Common Pitfalls

### Pitfall 1: Multiple `data-vue` Islands on Admin Pages Break Pinia State Sharing
**What goes wrong:** If any admin section is mounted as a separate `data-vue="SomethingElse"` element alongside `data-vue="AdminIsland"`, each gets its own Pinia instance. State changes in one are invisible to the other.
**Why it happens:** Developers add a small standalone widget (e.g., a notification badge in the Blade header) as a separate island because it seems simpler. The `app.js` mounter calls `createPinia()` per island.
**How to avoid:** The Blade admin layout mounts exactly one `data-vue="AdminIsland"` element. Everything interactive in the admin UI lives inside this island. The `ModalProvider` island that exists in `home.blade.php` is not present in `admin.blade.php`.
**Warning signs:** Two `data-vue` attributes on the same admin Blade page.

### Pitfall 2: Vue Router 4 vs Vue Router 5 Version Confusion
**What goes wrong:** `npm install vue-router` without a version pin installs 5.0.4 (the current `latest` tag as of March 2026). Vue Router 5 has a different API (particularly around `createRouter` and composables) that may not be compatible with the existing project's Vue 3.5.30.
**Why it happens:** npm's latest tag now points to 5.x.
**How to avoid:** Pin explicitly: `npm install vue-router@^4.5.0`. Confirm `"vue-router": "^4.x.x"` in package.json after install.
**Warning signs:** `TypeError: createRouter is not a function` or missing `useRouter` composable.

### Pitfall 3: Laravel Route Order — Catch-All Must Come After API Proxy Routes
**What goes wrong:** If the catch-all `Route::get('/{any?}', ...)` for admin pages is registered before the `/admin/api/*` proxy routes, ALL admin requests — including API calls — will be served by the Blade template.
**Why it happens:** The catch-all uses a wildcard that matches everything under `/admin/`, including `/admin/api/programs`.
**How to avoid:** Register ALL `/admin/api/*` proxy routes BEFORE the catch-all page route. In Laravel, routes are matched in registration order.
**Warning signs:** Admin API axios calls returning HTML instead of JSON (the Blade template HTML is returned instead of proxied JSON).

### Pitfall 4: history Mode Vue Router Requires Server-Side Catch-All
**What goes wrong:** Vue Router in hash mode (`createWebHashHistory`) would work without server-side changes but produces URLs like `/admin#/groups`. History mode (`createWebHistory`) produces clean URLs like `/admin/groups` but requires every URL to return the same HTML shell from the server.
**Why it happens:** History mode is required (locked decision), but forgetting to add the server catch-all means a direct navigation to `/admin/groups` returns a 404 from Laravel because no route matches `/admin/groups` specifically.
**How to avoid:** Register the catch-all Laravel route for `/admin/{any?}` before any CRUD routes exist. This is done in Phase 5.
**Warning signs:** `/admin/groups` (typed directly in browser or on refresh) returns 404 or redirect.

### Pitfall 5: Leader Detection — `/auth/me/linked-user` vs `googleEmail` Prop
**What goes wrong:** CONTEXT.md says "call `/auth/me/linked-user` to check" for leader detection. But the existing codebase already passes `googleEmail` to `NavigationIsland` from Blade, populated from the session response. Using the existing prop is simpler and avoids an extra API call on every member page load.
**Why it happens:** The context was written referencing the React SPA behavior. The Blade+Vue architecture already has a simpler path.
**How to avoid:** For SHELL-04 (member nav "Group Leader Admin" link), use the `googleEmail` prop already available in `navigation-island.vue`. No additional API call needed.
**Warning signs:** A new `onMounted` fetch in `navigation-island.vue` to an endpoint that returns the same data already in the component's props.

---

## Code Examples

### Admin Route Registration (Catch-All Pattern)

```php
// routes/web.php — replace the existing /admin stub with this group
Route::middleware('member.auth')->prefix('admin')->name('admin.')->group(function () {

    // Phase 6+ will add API proxy routes here, before the catch-all:
    // Route::match([...], '/api/{path}', ...)->where('path', '.*')->name('api.proxy');

    // Catch-all: serves admin Blade shell for ALL /admin/* page paths
    // MUST be the LAST route in this group
    Route::get('/{any?}', [AdminController::class, 'show'])
        ->where('any', '.*')
        ->name('shell');
});
```

### AdminIsland Root Component

```typescript
// resources/js/islands/admin-island/admin-island.vue
<script setup lang="ts">
import { onMounted } from 'vue'
import { RouterView } from 'vue-router'
import axios from 'axios'
import AdminSidebar from './components/admin-sidebar.vue'

interface Props {
  avatarUrl?: string
  initials?: string
  memberName?: string
  googleEmail?: string
  logoutUrl?: string
}

const props = withDefaults(defineProps<Props>(), {
  initials: '?',
  logoutUrl: '/logout',
})

onMounted(() => {
  // Configure CSRF token for all admin axios calls — done once here, applies globally
  const meta = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')
  if (meta?.content) {
    axios.defaults.headers.common['X-CSRF-TOKEN'] = meta.content
  }
})
</script>

<template>
  <div class="AdminLayout">
    <AdminSidebar
      :avatar-url="props.avatarUrl"
      :initials="props.initials"
      :member-name="props.memberName"
      :logout-url="props.logoutUrl"
    />
    <main class="AdminLayout__content">
      <RouterView />
    </main>
  </div>
</template>
```

### app.js Registration with Router

```javascript
// resources/js/app.js — modified to support AdminIsland with Vue Router
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import AdminIsland from './islands/admin-island/admin-island.vue'
import { router as adminRouter } from './islands/admin-island/router'
// ... other existing imports ...

const componentRegistry = {
  // ... existing components ...
  'AdminIsland': AdminIsland,
}

document.querySelectorAll('[data-vue]').forEach((el) => {
  const name = el.dataset.vue
  const Component = componentRegistry[name]
  if (!Component) {
    console.warn(`[Vue islands] No component registered for "${name}"`)
    return
  }
  const props = el.dataset.props ? JSON.parse(el.dataset.props) : {}
  const app = createApp(Component, props)
  app.use(createPinia())
  if (name === 'AdminIsland') {
    app.use(adminRouter)
  }
  app.mount(el)
})
```

### Navigation Island — Add "Group Leader Admin" Link

```vue
<!-- navigation-island.vue — add at TOP of NavigationMenuContent in avatar menu -->
<!-- Condition: googleEmail prop is truthy (member has a linked Google account) -->
<a
  v-if="googleEmail"
  href="/admin"
  class="Button Button--secondary Button--size-default Button--mode-block"
>
  <span class="Button__content">
    <span class="Button__icon Button__icon--left">
      <!-- LayoutDashboard icon (lucide equivalent) -->
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect width="7" height="9" x="3" y="3" rx="1"/><rect width="7" height="5" x="14" y="3" rx="1"/>
        <rect width="7" height="5" x="14" y="12" rx="1"/><rect width="7" height="9" x="3" y="12" rx="1"/>
      </svg>
    </span>
    <span class="Button__label">Group Leader Admin</span>
  </span>
</a>
```

**Note:** This `<a href="/admin">` is a full-page navigation (intentional — switching experiences is a context switch, not an in-app navigation). The link uses the existing Button BEM classes, consistent with the Profile and Account buttons already in the menu.

### Admin Sidebar SCSS Skeleton (Claude's Discretion)

```scss
// resources/css/layouts/admin-layout.scss
.AdminLayout {
  display: flex;
  height: 100vh;
  background: #1a1d2e; // dark background — same token as member experience
}

.AdminLayout__content {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
  max-width: 1200px; // Claude's discretion — centered constrained content
  margin: 0 auto;
}

// resources/css/components/admin/admin-sidebar.scss
.AdminSidebar {
  width: 56px; // collapsed (icon-only)
  background: #252936;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16px 0;
  transition: width 0.2s ease;
  overflow: hidden;

  &:hover,
  &--expanded {
    width: 220px; // expanded (shows labels)
    align-items: flex-start;
  }
}
```

---

## State of the Art

| Old Approach | Current Approach | Impact for Phase 5 |
|--------------|------------------|-------------------|
| Per-island Pinia instances (v1.0 member experience) | Single AdminIsland with one Pinia instance | Admin sections share state; no workarounds needed |
| Full page reloads for admin navigation (placeholder stub) | Vue Router history mode inside island | No reload between Dashboard/Groups/Programs/Profile |
| vue-router 3.x (Vue 2 era) | vue-router 4.x (Vue 3 compatible) | Composition API `useRouter()` / `useRoute()` work natively |

**Deprecated/outdated:**
- Vue Router 3.x: Vue 2 only. Do not use.
- Vue Router 5: in early release as of 2026; not yet LTS. Do not use.
- `hash mode` routing: Produces `/admin#/groups` URLs. Not used — history mode is the locked decision.

---

## Open Questions

1. **SHELL-05: Redirect target for unauthenticated admin access**
   - What we know: `CheckMemberSession` redirects to `/` (public home) on failed auth. SHELL-05 says "redirected to login."
   - What's unclear: Does SHELL-05 require changing the redirect target from `/` to `/login`, or is the existing behavior acceptable?
   - Recommendation: Change the middleware redirect from `redirect('/')` to `redirect('/login')` — this is a one-line change to `CheckMemberSession.php` with no side effects (unauthenticated member pages will also redirect to login, which is better UX). However, this affects ALL protected routes, not just admin. The planner should decide scope.

2. **Admin route naming collision**
   - What we know: The current route is named `'admin'` (used in `AdminTest.php` via `route('admin')`). The catch-all will replace this.
   - What's unclear: Whether changing the route name from `'admin'` to `'admin.shell'` breaks existing tests.
   - Recommendation: Keep the catch-all named `'admin'` OR update `AdminTest.php` simultaneously. The existing test `test_admin_route_is_registered` asserts `route('admin')` resolves — this must still pass.

3. **Avatar menu implementation in admin vs member experience**
   - What we know: Member experience uses `navigation-island.vue`'s avatar menu (modal stack pattern via Teleport). Admin has a sidebar avatar that opens a dropdown.
   - What's unclear: Whether the admin avatar dropdown should reuse the same Teleport modal pattern, or use a simpler inline dropdown (since the sidebar is full-height and the dropdown needs to appear near the avatar at the bottom).
   - Recommendation: Simple inline Vue `v-if` dropdown inside AdminSidebar component — no Teleport needed. The sidebar is full-height fixed; z-index layering is predictable. This is simpler than the modal stack pattern.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel feature tests) |
| Config file | `phpunit.xml` |
| Quick run command | `php artisan test --filter AdminTest` |
| Full suite command | `php artisan test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHELL-01 | Leader can access `/admin` when authenticated | Feature | `php artisan test --filter AdminTest::test_admin_page_renders_for_leader` | ✅ AdminTest.php (existing — will need update for new Blade content) |
| SHELL-02 | Admin layout renders sidebar navigation | Feature (SSR HTML) | `php artisan test --filter AdminShellTest::test_admin_layout_contains_sidebar` | ❌ Wave 0 |
| SHELL-03 | Avatar menu on admin shows "Member Experience" link | Feature (SSR HTML) | `php artisan test --filter AdminShellTest::test_admin_avatar_menu_has_member_experience_link` | ❌ Wave 0 |
| SHELL-04 | Member nav shows "Group Leader Admin" for leaders | Feature (SSR HTML) | `php artisan test --filter AdminShellTest::test_member_nav_shows_admin_link_for_google_linked_member` | ❌ Wave 0 |
| SHELL-04 | Member nav hides "Group Leader Admin" for non-leaders | Feature (SSR HTML) | `php artisan test --filter AdminShellTest::test_member_nav_hides_admin_link_when_no_google_link` | ❌ Wave 0 |
| SHELL-05 | Unauthenticated access to `/admin` redirects | Feature | `php artisan test --filter AdminTest::test_admin_page_redirects_unauthenticated` | ✅ AdminTest.php (existing) |
| SHELL-05 | Unauthenticated access to `/admin/groups` redirects | Feature | `php artisan test --filter AdminShellTest::test_admin_subpath_redirects_unauthenticated` | ❌ Wave 0 |
| SHELL-06 | Admin page HTML contains `data-vue="AdminIsland"` mount point | Feature (SSR HTML) | `php artisan test --filter AdminShellTest::test_admin_page_mounts_admin_island` | ❌ Wave 0 |
| SHELL-07 | Vue Router routes registered (smoke — JS inspection not possible in PHPUnit) | Feature (SSR HTML) | `php artisan test --filter AdminShellTest::test_admin_subpaths_served_by_same_blade_template` | ❌ Wave 0 |

**Note on SHELL-06 and SHELL-07:** PHPUnit cannot execute JavaScript. Tests for Vue Router client-side behavior validate the server-side preconditions: the catch-all route serves the admin Blade template for all `/admin/*` paths, and the Blade template contains the AdminIsland mount point. Vue Router's client-side behavior is verified manually in the browser.

### Sampling Rate
- **Per task commit:** `php artisan test --filter AdminTest`
- **Per wave merge:** `php artisan test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/Feature/AdminShellTest.php` — covers SHELL-02, SHELL-03, SHELL-04, SHELL-06, SHELL-07 (server-side preconditions)
- [ ] `tests/Feature/AdminTest.php` — existing file will need updates as admin page Blade content changes (existing assertions check for placeholder text that will be replaced)

*(Existing `AdminTest.php` covers SHELL-01 and SHELL-05 already, but the assertions checking for `'Jane'`, `'Smith'`, `'(555) 000-1111'`, and `'MakeReady Admin'` page header text will need to be revised when the Blade template structure changes.)*

---

## Sources

### Primary (HIGH confidence)
- `/Users/lukekeith/www/makeready/client/resources/js/app.js` — confirmed island mount pattern (`createApp` + `createPinia()` per island), componentRegistry structure
- `/Users/lukekeith/www/makeready/client/resources/js/stores/modal.store.ts` — confirmed Pinia composition style (`defineStore` + `ref`/`computed`)
- `/Users/lukekeith/www/makeready/client/resources/js/components/domain/navigation-island/navigation-island.vue` — confirmed `googleEmail` prop exists and is used for Google account display; CSRF fallback to `meta[name="csrf-token"]` already present
- `/Users/lukekeith/www/makeready/client/app/Services/ApiService.php` — confirmed `delete()` method absent; existing `patch()` method is the template for adding it
- `/Users/lukekeith/www/makeready/client/routes/web.php` — confirmed `/admin` route exists as a single GET, guarded by `member.auth` middleware; confirmed route naming convention
- `/Users/lukekeith/www/makeready/client/resources/views/layouts/home.blade.php` — confirmed `<meta name="csrf-token">` present; confirmed Vite asset loading
- `/Users/lukekeith/www/makeready/client/app/Http/Middleware/CheckMemberSession.php` — confirmed redirect to `/` on failed auth; confirmed `member` data available via `$request->attributes`
- `/Users/lukekeith/www/makeready/client/tests/Feature/AdminTest.php` — confirmed existing test coverage and assertions that must remain passing
- `/Users/lukekeith/www/makeready/client/package.json` — confirmed `vue-router` is NOT currently installed; confirmed `lucide-vue-next` and `reka-ui` are available
- `npm view vue-router version` — confirmed latest tag is 5.0.4; vue-router 4.x is the Vue 3 LTS choice

### Secondary (MEDIUM confidence)
- Vue Router 4 official documentation — `createWebHistory`, `createRouter`, `RouterView`, `RouterLink`, `useRouter`, `useRoute` Composition API
- Pinia documentation — store isolation per `createPinia()` instance; confirmed single-instance pattern required for cross-section state sharing

### Tertiary (LOW confidence)
- None for Phase 5 — all findings based on direct codebase inspection or official library documentation

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions from direct package.json inspection and npm registry
- Architecture patterns: HIGH — based on actual codebase inspection (app.js, navigation-island.vue, ApiService.php, routes/web.php)
- Pitfalls: HIGH — Pinia isolation and CSRF pitfalls verified directly from codebase; Vue Router version confusion is observable fact (npm shows 5.0.4 as latest)
- Leader detection: HIGH — `googleEmail` prop path confirmed through 4 separate Blade page templates

**Research date:** 2026-03-19
**Valid until:** 2026-06-19 (90 days — stable stack; `vue-router` major version situation warrants re-check if implementation is delayed beyond June 2026)
