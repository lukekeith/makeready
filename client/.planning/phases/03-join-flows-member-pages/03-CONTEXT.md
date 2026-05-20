# Phase 3: Join Flows + Member Pages - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire the Blade component library into real page templates with API data. Implement all join flows (group, study, event), member login, and authenticated member pages (home, groups list, group home, profile). Each page fetches data from the MakeReady API via the cookie-proxy ApiService and renders server-side via Blade.

</domain>

<decisions>
## Implementation Decisions

### Join Flow Architecture
- Multi-step state persisted in **Laravel session** between requests
- **Single Blade view with conditional step sections** — one template per join type (group, event, study), showing the right step based on session state
- **One route with step parameter**: `/join/group/{code}/{step?}` — step defaults to first (info)
- Phone entry and code verification use **Vue islands** (PhoneEntry, VerifyCode) mounted in the Blade template
- Vue interactive components submit via **AJAX + redirect** — send data to Laravel endpoint, get redirect URL back
- SMS consent checkbox placement: **match React app** (wherever it currently appears in the join flow)
- Server-side enforcement of SMS consent: Laravel controller rejects POST if consent not checked

### API Data Loading Pattern
- **All data loaded upfront** in the controller before rendering
- Controller calls ApiService, passes results to Blade view as variables
- Error handling: **match React app** behavior (inline error messages where content would be)
- Empty states: use the Blade `<x-primitive.empty-state>` component

### Member Page Layouts
- **Two Blade layout files**: `resources/views/layouts/auth.blade.php` (centered, for join/login) and `resources/views/layouts/home.blade.php` (nav + content, for authenticated pages)
- Pages `@extend` the appropriate layout
- Navigation account menu uses the **Vue modal system** (Pinia store opens bottom sheet — matches React behavior)

### Route Structure
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

</decisions>

<specifics>
## Specific Ideas

- "I wanted the original design preserved without any changes" — every page must look identical to the React version
- Join flow steps from React: code → group info → profile → phone → verify → confirmed
- The MCP server has full API documentation — use it to find the right endpoints for each page
- `GET /api/members/session` checks auth (cookie-based)
- `POST /api/members/verify-phone` sends SMS code
- `POST /api/members/confirm-verification` verifies code + creates session
- `GET /api/groups/code/{code}` looks up group by join code

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `app/Services/ApiService.php`: Cookie-proxy API client (get/post with cookie forwarding)
- `app/Http/Middleware/CheckMemberSession.php`: Auth middleware (`member.auth`)
- `app/View/helpers.php`: PHP `cva()` helper for variant classes
- 52 Blade components at `resources/views/components/` (primitive/domain/layout/panel)
- 8 Vue interactive components at `resources/js/components/` (PhoneEntry, VerifyCode, etc.)
- `resources/js/stores/modal.store.ts`: Pinia modal store for menus/overlays
- `resources/views/layouts/app.blade.php`: Current shared layout (needs splitting into auth + home)

### Established Patterns
- Controllers call `ApiService->get()`/`->post()` with `$request` for cookie forwarding
- API responses: `['status' => int, 'body' => array, 'setCookies' => array]`
- Set-Cookie headers forwarded to browser response via `$response->header('Set-Cookie', $cookie, false)`
- Blade components: `<x-primitive.button variant="primary">`, `<x-domain.group-card :group="$group">`
- Auth check: middleware calls `/api/members/session`, stores member in `$request->attributes`

### Integration Points
- `routes/web.php`: Add all Phase 3 routes
- `resources/views/layouts/`: Create auth.blade.php and home.blade.php from current app.blade.php
- `app/Http/Controllers/`: Create controllers for each page group (JoinController, MemberController, GroupController, etc.)
- Vue islands mount via `data-vue` attributes in Blade templates

### React Route → Laravel Route Mapping (reference)
- `/` → `/` (public home)
- `/login` → `/login` (member login)
- `/home` → `/home` (authenticated home — already exists)
- `/groups` → `/groups` (groups list)
- `/groups/:groupId` → `/groups/{groupId}` (group home)
- `/join` → `/join` (enter code)
- `/join/group/:code` + steps → `/join/group/{code}/{step?}`
- `/event/:code` + steps → `/event/{code}/{step?}`
- `/study/:identifier` → `/join/study/{identifier}/{step?}`
- `/profile` → `/profile` (member profile)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-join-flows-member-pages*
*Context gathered: 2026-03-17*
