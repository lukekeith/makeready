# Phase 4: Content + Admin + Cutover — Research

**Researched:** 2026-03-18
**Domain:** Laravel Blade + Vue islands, lesson activity SPA island, HLS video, SOAP journal, admin page, Railway cutover
**Confidence:** HIGH (pattern is established from Phase 3; new complexity is the Vue lesson island)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Lesson activity page**: Single Blade shell + one large Vue component island manages all step transitions client-side (SPA feel). Not per-step Blade pages.
- **HLS video**: Via VideoPlayer Vue component using hls.js (already installed). Client-only rendered with isMounted guard.
- **SOAP journal**: Via BulletTextInput Vue component (contenteditable, already built). Save behavior matches React app — POST to `/api/member/activities/{id}/submit`.
- **Admin panel**: Full feature parity with React admin page. Protected by `member.auth` middleware + leader role check.
- **Cutover**: Replace in-place on Railway. Keep React on `archive/react-spa` branch as rollback. CI/CD already updated in Phase 1.

### Claude's Discretion
- Exact Vue lesson island component structure (how steps are organized internally)
- Tiptap configuration and toolbar options — **CONTEXT says BulletTextInput, which is already built (contenteditable), NOT Tiptap. Tiptap is NOT installed. Use BulletTextInput.**
- Admin page layout and organization
- Error page design
- Study code entry page
- Preview page data loading

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CONT-01 | Study home page with lesson list migrated | Controller fetches `/api/groups/{groupId}/study-enrollment/{id}?memberId=...`; Blade renders StudyCard list; StudyCard Blade component already exists |
| CONT-02 | Lesson activity page with steps migrated | Vue island `LessonIsland` receives lesson JSON as prop from controller; manages VIDEO/READ/USER_INPUT/COMPLETE step transitions; uses existing VideoPlayer + BulletTextInput + Blade components |
| CONT-03 | HLS video playback working in Vue (client-only) | VideoPlayer Vue component already built with `isMounted` guard; receives `src` prop; emits progress events; wired into island via Vue event system |
| CONT-04 | Rich text editor for SOAP journal | BulletTextInput Vue component already built (contenteditable); receives `modelValue` + emits `update:modelValue`; used inside LessonIsland |
| CONT-05 | Lesson preview for non-members | Public route `/public/preview/{token}/lesson/{lessonId}/{step}`; controller fetches `/public/preview/{token}/lesson/{lessonId}`; same LessonIsland component, preview mode flag |
| CONT-06 | Study preview for non-members | Public route `/public/preview/{token}`; controller fetches `/public/preview/{token}`; Blade page with StudyCard list |
| CONT-07 | Study code entry page | Auth layout Blade shell + form that redirects to `/join/study/{code}`; uses JoinCodePage Blade component |
| ADMN-01 | Admin panel for organization leaders | Protected route + leader check middleware/gate; Blade page showing member info; matches React admin (name, phone display, logout button) |
| INFR-03 | 404 not found page | Laravel `resources/views/errors/404.blade.php` + `abort(404)` pattern |
| INFR-04 | Error handling and user-friendly error display | Laravel exception handler renders `resources/views/errors/{code}.blade.php`; generic 500 view; custom exception handler in `bootstrap/app.php` |
</phase_requirements>

---

## Summary

Phase 4 completes the migration: it adds the last content pages (study home, lesson activity, previews, study code), admin panel, infrastructure pages (404/errors), and executes the production cutover. The vast majority of infrastructure is already in place — 52 Blade components, 8 Vue islands, the controller/ApiService/cookie-proxy pattern, `member.auth` middleware, and 133 passing tests.

The highest-complexity deliverable is the **Vue lesson island**. This is a standalone Vue SPA embedded in a Blade shell that receives the full lesson JSON upfront and manages VIDEO → READ → USER_INPUT → COMPLETE step transitions entirely client-side, with AJAX calls back to the API for saving progress and notes. All sub-components (VideoPlayer, BulletTextInput, Blade components rendered server-side as static markup that the island doesn't touch) are already built — the work is orchestrating them inside a new Vue component.

The **admin page** in React is intentionally simple: it shows the authenticated member's name and phone with a logout button. "Full feature parity" means exactly replicating that display — no CRUD, no organization management, no complex admin features.

**Production cutover** requires: registering the lesson island in `app.js`, adding ~10 new routes to `web.php`, adding a `resources/views/errors/` directory with 404/500 templates, and pushing to Railway. No infrastructure changes beyond what was done in Phase 1.

**Primary recommendation:** Build LessonIsland as a self-contained Vue SFA that receives `lessonData` + `groupId` + `lessonScheduleId` + `isPreview` props, handles all step state internally with Pinia or `ref()`, and calls the API via `axios` for note saves and video progress. Register it in `app.js` like all other islands.

---

## Standard Stack

### Core (all already installed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | `^3.5.30` | Lesson island + component reactivity | Already in use for all other islands |
| Pinia | `^3.0.4` | Island-level state management | Already used in join islands; consistent pattern |
| hls.js | `^1.6.15` | HLS video streaming | Already installed; VideoPlayer uses it |
| axios | `^1.11.0` | AJAX from island to API proxy | Already in bootstrap; used in join islands |

### Nothing new to install

All required libraries are already in `package.json`. The CONTEXT.md mentions "Tiptap" but the actual implementation decision was to use **BulletTextInput** (already built as a contenteditable Vue component). No Tiptap installation is needed. Confirm this before planning: SOAP notes are plain text stored as strings, which BulletTextInput already handles correctly.

### Key installed but not yet wired

| Component | File | Status |
|-----------|------|--------|
| VideoPlayer | `resources/js/components/domain/video-player/video-player.vue` | Built, registered in `app.js` |
| BulletTextInput | `resources/js/components/primitive/bullet-text-input/bullet-text-input.vue` | Built, registered in `app.js` |
| LessonPageHeader | `resources/views/components/domain/lesson-page-header.blade.php` | Built, server-rendered only |
| StepIndicator | `resources/views/components/primitive/step-indicator.blade.php` | Built, server-rendered only |
| StudyCard | `resources/views/components/domain/study-card.blade.php` | Built |
| StudyScheduleCard | `resources/views/components/domain/study-schedule-card.blade.php` | Verify exists |
| Confirmation | `resources/views/components/panel/confirmation.blade.php` | Built |
| Loading | `resources/views/components/primitive/loading.blade.php` | Built |

---

## Architecture Patterns

### Established Pattern: Controller → ApiService → Blade → Vue Island

Every authenticated page in Phase 3 follows this pattern exactly:

```
HTTP GET /groups/{groupId}/study/{studyEnrollmentId}
  → StudyHomeController::show()
    → $api->get('/api/groups/{groupId}/study-enrollment/{id}?memberId=...')
    → response()->view('pages.study-home', compact('member', 'studyData', ...))
    → forward Set-Cookie headers
  → Blade renders full HTML with data
  → Vue island mounts (if interactive elements needed)
```

The lesson page is the same, but the Vue island handles ALL step rendering rather than Blade handling the content directly.

### Pattern 1: Lesson Island Architecture

**What:** A single Vue SFA mounted in a Blade shell. Controller fetches the complete lesson JSON upfront and passes it via `data-props`. The island owns all step state.

**When to use:** Any page that needs SPA-like client-side navigation without page reloads.

**Blade shell (lesson page):**
```php
// LessonController::show()
public function show(Request $request, string $groupId, string $lessonScheduleId, int $step = 1)
{
    $member = $request->attributes->get('member');
    $memberId = $member['id'] ?? '';

    $lessonResult = $this->api->get(
        "/api/member/lessons/{$lessonScheduleId}?memberId={$memberId}",
        $request
    );

    if ($lessonResult['status'] !== 200) {
        abort(404);
    }

    $lessonData = $lessonResult['body']['lesson'] ?? null;

    $response = response()->view('pages.lesson', compact(
        'member', 'groupId', 'lessonScheduleId', 'lessonData', 'step'
    ));

    foreach ($lessonResult['setCookies'] as $cookie) {
        $response->header('Set-Cookie', $cookie, false);
    }

    return $response;
}
```

**Blade page template:**
```blade
{{-- resources/views/pages/lesson.blade.php --}}
@extends('layouts.home')
@section('title', 'Lesson — MakeReady')
@section('content')
<main class="LessonPage">
    <div
        data-vue="LessonIsland"
        data-props="{{ json_encode([
            'lessonData'        => $lessonData,
            'groupId'           => $groupId,
            'lessonScheduleId'  => $lessonScheduleId,
            'initialStep'       => $step,
            'isPreview'         => false,
        ]) }}"
    ></div>
</main>
@endsection
```

**Registration in app.js:**
```javascript
import LessonIsland from './components/domain/lesson-island/lesson-island.vue'
// Add to componentRegistry:
'LessonIsland': LessonIsland,
```

### Pattern 2: Vue Island Step Management

**What:** The LessonIsland manages current step as reactive state. Step transitions happen entirely in JS — no page navigation. The Blade shell URL stays the same (or can use `history.pushState` for shareable links).

**Step types from API:**
- `VIDEO` — render VideoPlayer Vue component
- `READ` — render scripture/text blocks (static Blade-rendered or in-island Vue rendering)
- `USER_INPUT` — render BulletTextInput + save note via AJAX
- `COMPLETE` — render completion screen with back button

**Internal island structure:**
```
lesson-island/
├── lesson-island.vue          ← Root: manages step state, wraps header + content
├── steps/
│   ├── video-step.vue         ← Wraps VideoPlayer, tracks progress
│   ├── read-step.vue          ← Renders scripture/text blocks
│   ├── input-step.vue         ← BulletTextInput + save logic
│   └── complete-step.vue      ← Completion screen
```

**Key island props interface:**
```typescript
interface Props {
  lessonData: ILesson        // Full lesson object from API
  groupId: string
  lessonScheduleId: string
  initialStep: number        // From controller (URL param)
  isPreview: boolean         // false for authenticated, true for public preview
}
```

**Step navigation state:**
```typescript
const currentStepNumber = ref(props.initialStep)
const steps = computed(() => buildStepList(props.lessonData.activities))
const currentStep = computed(() => steps.value[currentStepNumber.value - 1])
```

### Pattern 3: AJAX Save from Island

**What:** Island POSTs note content to Laravel route (which proxies to API). No form submission — pure AJAX via axios.

**SOAP note save payload (matches React exactly):**
```typescript
// POST /api/member/activities/{lessonActivityId}/submit
// via Laravel proxy at same URL path
const payload = {
  lessonScheduleId: props.lessonScheduleId,
  note: {
    type: 'OBSERVATION' | 'APPLICATION' | 'PRAYER',  // from activity.noteType
    content: noteText,                                  // from BulletTextInput
  }
}
```

**Critical:** The island makes API calls to the MakeReady API through Laravel's cookie proxy. Laravel needs routes to forward these AJAX requests. Review whether existing routes cover `/api/member/activities/*/submit` or if Laravel needs a catch-all proxy route for lesson AJAX.

**Existing ApiService endpoints used by lesson:**
- `GET /api/member/lessons/{lessonScheduleId}?memberId={id}` — fetch full lesson (controller does this upfront)
- `POST /api/member/activities/{lessonActivityId}/submit` — save note + advance step
- `POST /api/member/activities/{lessonActivityId}/video-progress` — save video progress
- `GET /api/member/activities/{lessonActivityId}/video-progress?lessonScheduleId={id}` — fetch existing video progress
- `GET /api/bible/{translationCode}/{bookNumber}/{chapter}` — fetch scripture verses

**Open question:** Does the island call the MakeReady API directly (bypassing Laravel), or does it go through Laravel routes that proxy to the API? The join islands use `ajaxSubmitUrl` props pointing to Laravel routes. The lesson island will need the same — Laravel proxy routes for each AJAX endpoint used during lesson activity.

### Pattern 4: Public Preview Routes

**What:** Preview pages are public (no auth). The controller fetches from `/public/preview/{token}` (API endpoint) and renders server-side. The lesson preview reuses the LessonIsland with `isPreview: true`.

**Endpoints:**
- Study preview: `GET /public/preview/{token}` → returns `{ program, lessons }`
- Lesson preview: `GET /public/preview/{token}/lesson/{lessonId}` → returns `{ lesson }` (no memberId)

**Preview lesson island difference:** No note saving (or saves locally only). No auth check. Completion screen shows "Preview Complete" and links back to study preview.

### Pattern 5: Laravel Error Pages

**What:** Laravel looks for `resources/views/errors/{code}.blade.php`. The exception handler in `bootstrap/app.php` can be customized.

**Standard files needed:**
```
resources/views/errors/
├── 404.blade.php   — Not Found (INFR-03)
└── 500.blade.php   — Server Error (INFR-04)
```

**Implementation:**
```php
// bootstrap/app.php — add to withExceptions():
->withExceptions(function (Exceptions $exceptions): void {
    $exceptions->render(function (\Symfony\Component\HttpKernel\Exception\NotFoundHttpException $e, $request) {
        return response()->view('errors.404', [], 404);
    });
})
```

Laravel also auto-serves `errors/{code}.blade.php` for HTTP exceptions if the file exists — no explicit registration needed for standard HTTP error codes.

### Pattern 6: Admin Leader Check

**What:** React admin page checks `session.isMemberAuthenticated` and `session.member.role === 'leader'` (or similar). In Laravel, the `member.auth` middleware already injects `$member` into `$request->attributes`. A leader check can be added as a controller-level gate or second middleware.

**React admin review:** The React admin page (`archive/react-spa:src/pages/admin/admin.page.tsx`) is intentionally simple — it displays the member's name, shows their phone, and has a logout button. No CRUD operations. No organization/group management. The "full feature parity" means replicating this display only.

**Leader check approach:**
```php
// In AdminController::show()
$member = $request->attributes->get('member');
if (($member['role'] ?? '') !== 'leader') {
    abort(403);
}
```

Or add a dedicated `RequireLeaderRole` middleware that reads from the injected member attribute. The middleware approach keeps controllers clean.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Video streaming | Custom `<video>` with HLS parsing | VideoPlayer Vue component (already built) | Handles hls.js lifecycle, isMounted SSR guard, progress tracking, volume persistence |
| Rich text input | Tiptap or Lexical | BulletTextInput Vue component (already built) | contenteditable with bullet list support; same interface as React; no new dependencies |
| Cookie proxy | Custom Guzzle middleware | `$api->get/post/patch()` methods in ApiService | Handles cookie forwarding, Set-Cookie extraction from Guzzle PSR-7 response already |
| Vue island mounting | Custom mounting logic | `data-vue` + `app.js` auto-mounter | Established pattern; all islands use it |
| Auth check | Custom session parsing | `member.auth` middleware (already registered) | Calls API, injects member, forwards cookies |
| Error pages | Custom exception middleware | `resources/views/errors/{code}.blade.php` | Laravel convention; auto-served by framework |
| Step indicator UI | Custom progress bar | `x-primitive.step-indicator` Blade component | Already built and styled |

**Key insight:** The lesson island appears complex because it orchestrates many steps, but all sub-components exist. The work is writing the orchestration logic in one `lesson-island.vue` file and wiring up AJAX save routes.

---

## Common Pitfalls

### Pitfall 1: Island Making Direct API Calls (Bypassing Laravel Proxy)

**What goes wrong:** Island uses `axios.post('https://api.makeready.org/...')` directly. CORS blocks the request. Auth cookies don't transfer. Tests can't fake it.

**Why it happens:** Feels natural to call the API directly from Vue.

**How to avoid:** Island AJAX always goes through Laravel routes (e.g., `POST /lesson/{scheduleId}/activity/{actId}/submit`). Laravel proxies to API via ApiService. This mirrors the join island pattern (they post to `/login/phone` which Laravel handles).

**Warning signs:** Any hardcoded `api.makeready.org` URL in Vue files.

### Pitfall 2: Lesson Data Stale After Note Save

**What goes wrong:** After saving a note, the island still shows the old step data. The React store refreshes the full lesson from the API response (`response.lesson` in `ISubmitActivityResponse`). The Vue island must do the same.

**Why it happens:** Assuming the API is fire-and-forget. The submit response actually returns the updated lesson.

**How to avoid:** After `POST .../submit`, replace `lessonData` in reactive state with `response.lesson` from the response body. This advances `completedAt`, updates `progress`, and reveals the next step correctly.

### Pitfall 3: HLS Not Loading Due to SSR Guard Timing

**What goes wrong:** VideoPlayer tries to import hls.js during server-side PHP rendering (doesn't happen — Vue renders client-side via Vite), or tries to attach HLS before the `<video>` element is in the DOM.

**Why it happens:** Missing `isMounted` check. VideoPlayer already has `onMounted(() => { isMounted.value = true })` and uses `v-if="isMounted"` — ensure this guard stays in place.

**How to avoid:** The VideoPlayer is already correct. Do NOT remove the `isMounted` guard.

### Pitfall 4: Scripture AJAX Calls Blocking Step Transitions

**What goes wrong:** READ steps require fetching Bible verses via `/api/bible/{translation}/{book}/{chapter}`. If the island blocks on this, navigation feels slow.

**Why it happens:** Awaiting scripture fetch before rendering step.

**How to avoid:** Prefetch scripture refs on mount (like the React store does) or show a loading state per-block. Controller fetches the lesson upfront but NOT scripture — scripture calls happen from the island. Use `Promise.all()` to fetch in parallel on mount.

### Pitfall 5: Admin Leader Role Check Missing

**What goes wrong:** Any authenticated member can visit `/admin`, not just leaders.

**Why it happens:** `member.auth` middleware only checks authentication, not role.

**How to avoid:** Add an explicit role check in `AdminController::show()` or a dedicated middleware. Check the `member` object's role field (confirm field name via MCP API tools or archive store).

### Pitfall 6: Preview Lesson Island Attempting to Save Notes

**What goes wrong:** Preview mode tries to POST notes to the API, which requires auth and a real `lessonScheduleId`.

**Why it happens:** Reusing the same island component without disabling save behavior.

**How to avoid:** The island receives `isPreview: true`. When `isPreview` is true, disable/hide all save buttons and AJAX calls. Input steps show as read-only in preview mode.

### Pitfall 7: `history.pushState` Step URL vs. Controller Initial Step

**What goes wrong:** Island updates the URL via `history.pushState` as the user navigates steps, but on refresh the controller renders the correct step data. If the island ignores `initialStep` prop and always starts at step 1, deep-link sharing breaks.

**Why it happens:** Island initializes `currentStepNumber = ref(1)` ignoring the prop.

**How to avoid:** `const currentStepNumber = ref(props.initialStep)`. Controller always extracts `{step}` from URL and passes it as prop.

### Pitfall 8: Cutover — Active User Sessions

**What goes wrong:** During Railway cutover, users with active React sessions in the browser get a blank screen or auth errors when the new Laravel app responds with Blade.

**Why it happens:** The React SPA stored state in-memory (MobX). Laravel uses the API session cookie, which is the same cookie the API issued before cutover. Sessions should survive if the cookie name is unchanged.

**How to avoid:** No special handling needed — the session cookie is owned by the MakeReady API, not the React or Laravel app. Users already authenticated will remain authenticated through the Laravel cookie proxy. Cutover during low-traffic period (e.g., night) minimizes impact.

---

## Code Examples

Verified patterns from project source:

### Controller Upfront Data Load (Established Pattern)
```php
// Source: GroupHomeController.php (production code)
public function show(Request $request, string $groupId)
{
    $member = $request->attributes->get('member');
    $memberId = $member['id'] ?? '';

    $groupResult = $this->api->get("/api/groups/{$groupId}/public", $request);

    $groupData = null;
    if ($groupResult['status'] === 200 && is_array($groupResult['body'])) {
        $groupData = $groupResult['body']['group'] ?? $groupResult['body']['data'] ?? null;
    }

    $response = response()->view('pages.group-home', compact('member', 'groupId', 'groupData'));

    foreach ($groupResult['setCookies'] as $cookie) {
        $response->header('Set-Cookie', $cookie, false);
    }

    return $response;
}
```

### Vue Island Registration (Established Pattern)
```javascript
// Source: resources/js/app.js (production code)
const componentRegistry = {
  'JoinPhoneIsland': JoinPhoneIsland,
  // Add:
  'LessonIsland': LessonIsland,
}
document.querySelectorAll('[data-vue]').forEach((el) => {
  const name = el.dataset.vue
  const Component = componentRegistry[name]
  const props = el.dataset.props ? JSON.parse(el.dataset.props) : {}
  const app = createApp(Component, props)
  app.use(createPinia())
  app.mount(el)
})
```

### Vue Island Mounting in Blade
```blade
{{-- Pass lesson data as JSON prop --}}
<div
    data-vue="LessonIsland"
    data-props="{{ json_encode([
        'lessonData'       => $lessonData,
        'groupId'          => $groupId,
        'lessonScheduleId' => $lessonScheduleId,
        'initialStep'      => (int) $step,
        'isPreview'        => false,
        'apiBaseUrl'       => '',  // Relative — Laravel proxies
    ]) }}"
></div>
```

### SOAP Note Save API Shape (from archive source)
```typescript
// Source: archive/react-spa:src/store/domain/activities.domain.ts
// POST /api/member/activities/{lessonActivityId}/submit
const payload: ISubmitActivityRequest = {
  lessonScheduleId: 'abc123',
  note: {
    type: 'OBSERVATION',   // | 'APPLICATION' | 'PRAYER'
    content: 'My note text',
  },
  // OR for advancing without a note:
  action: 'skip_to_complete',
}
// Response contains updated `lesson` object — replace local lessonData with it
```

### Laravel Error Pages (Convention)
```php
// resources/views/errors/404.blade.php
@extends('layouts.home')
@section('title', '404 — MakeReady')
@section('content')
<main class="NotFoundPage">
    <span class="NotFoundPage__text">404</span>
</main>
@endsection
```

### Auth Middleware Pattern (Established)
```php
// Source: routes/web.php (production code)
Route::middleware('member.auth')->group(function () {
    Route::get('/admin', [AdminController::class, 'show'])->name('admin');
    // ... other protected routes
});
```

### BulletTextInput in Vue Island
```vue
<!-- Source: resources/js/components/primitive/bullet-text-input/bullet-text-input.vue -->
<BulletTextInput
  :modelValue="noteContent"
  @update:modelValue="noteContent = $event"
  placeholder="Start typing..."
  :autoFocus="true"
  :fill="true"
/>
```

---

## New Routes Required (web.php additions)

| Method | Path | Controller | Name | Auth |
|--------|------|-----------|------|------|
| GET | `/groups/{groupId}/study/{studyEnrollmentId}` | `StudyHomeController@show` | `study.home` | Yes |
| GET | `/groups/{groupId}/lessons/{lessonScheduleId}/{step?}` | `LessonController@show` | `lesson.show` | Yes |
| POST | `/groups/{groupId}/lessons/{lessonScheduleId}/activity/{activityId}/submit` | `LessonController@submitNote` | `lesson.activity.submit` | Yes |
| POST | `/groups/{groupId}/lessons/{lessonScheduleId}/activity/{activityId}/video-progress` | `LessonController@saveVideoProgress` | `lesson.video.progress` | Yes |
| GET | `/api/bible/{translation}/{book}/{chapter}` | `LessonController@fetchScripture` | `lesson.scripture` | No |
| GET | `/study` | `StudyCodeController@show` | `study.code` | No |
| GET | `/admin` | `AdminController@show` | `admin` | Yes |
| GET | `/public/preview/{token}` | `PreviewController@studyPreview` | `preview.study` | No |
| GET | `/public/preview/{token}/lesson/{lessonId}/{step?}` | `PreviewController@lessonPreview` | `preview.lesson` | No |

**Note on scripture route:** This proxies `/api/bible/...` through Laravel (keeping the island's AJAX calls server-proxied). Alternatively, the island could call the MakeReady API directly for scripture (it's public data). Decision to make during planning — server-proxied is more consistent.

---

## All API Endpoints Used in This Phase

| Endpoint | Method | Auth | Controller / Island | Notes |
|----------|--------|------|---------------------|-------|
| `/api/groups/{groupId}/study-enrollment/{id}?memberId={id}` | GET | Yes | StudyHomeController | Returns study + lesson list |
| `/api/member/lessons/{lessonScheduleId}?memberId={id}` | GET | Yes | LessonController (upfront) | Full lesson with activities, notes, progress |
| `/api/member/activities/{actId}/submit` | POST | Yes | LessonController (proxy) | Save note + advance step |
| `/api/member/activities/{actId}/video-progress` | GET/POST | Yes | LessonController (proxy) | Save/fetch video progress |
| `/api/bible/{translation}/{book}/{chapter}` | GET | No | LessonController (proxy) | Scripture verses for READ steps |
| `/public/preview/{token}` | GET | No | PreviewController | Study preview data |
| `/public/preview/{token}/lesson/{lessonId}` | GET | No | PreviewController | Lesson preview data |

---

## Cutover Checklist

The CONTEXT.md says CI/CD was updated in Phase 1 and environment variables are configured. The actual cutover steps are:

1. Merge all Phase 4 work to `main`
2. Push `main` — Railway CI/CD triggers and deploys Laravel
3. Verify with `curl -s https://app.makeready.org/ | grep 'MakeReady'` (server-rendered HTML visible)
4. Run smoke tests against production URL
5. If rollback needed: `git push railway archive/react-spa:main --force` (or redeploy from Railway dashboard using archive branch)

**Pre-cutover verification:**
- All routes in `web.php` added
- `LessonIsland` registered in `app.js`
- `resources/views/errors/` directory with 404 and 500 views
- PHPUnit suite passes (all 133+ tests green)
- Histoire stories pass visual inspection

---

## State of the Art

| Old Approach (React) | Current Approach (Laravel) | Notes |
|----------------------|----------------------------|-------|
| React Router for step navigation | `history.pushState` in Vue island | Island manages URL without full page nav |
| MobX store for lesson state | Vue `ref()` / Pinia store in island | Per-island state, not global |
| Lexical rich text editor | BulletTextInput (contenteditable) | Already ported in Phase 2 |
| apiClient (Express proxy) | ApiService (Laravel PHP proxy) | Same cookie-forwarding responsibility |
| React `<Route path="*">` for 404 | `resources/views/errors/404.blade.php` | Laravel convention |

---

## Open Questions

1. **Scripture API — proxied through Laravel or direct?**
   - What we know: React calls `/api/bible/{translation}/{book}/{chapter}` from the client directly. MakeReady API likely requires auth cookie for this.
   - What's unclear: Is the Bible API public (no cookie needed) or auth-gated?
   - Recommendation: Default to proxying through Laravel for consistency with all other AJAX. If confirmed public, island can call directly.

2. **Note type per activity — how does the island know which type to submit?**
   - What we know: `SubmitNoteType = 'OBSERVATION' | 'APPLICATION' | 'PRAYER'`. The activity object from the lesson has a `type` field (`USER_INPUT`), but the note type (SOAP letter) comes from a different field.
   - What's unclear: Does `ILessonActivity` have a `noteType` field, or is it derived from something else?
   - Recommendation: Inspect `ILessonActivity` interface in archive source before building the island. The `helpTitle` field (e.g., "Observation") likely indicates the SOAP step type.

3. **Tiptap vs BulletTextInput — CONTEXT.md mentions both**
   - What we know: The CONTEXT.md mentions "Tiptap Vue component (BulletTextInput)". The actual BulletTextInput component is a contenteditable component built in Phase 2, NOT Tiptap. Tiptap is not installed.
   - Recommendation: Use BulletTextInput as-is. No Tiptap installation needed. The CONTEXT wording appears to conflate the two.

4. **Admin leader role field name**
   - What we know: React admin checks `session.isMemberAuthenticated`. The admin page in React does NOT check a leader role — it just shows member info and is accessible to any authenticated member. The CONTEXT.md says "leader role check", but the React implementation doesn't have one.
   - What's unclear: Should Laravel add a leader check that React didn't have, or replicate React exactly (any auth member can visit `/admin`)?
   - Recommendation: Check whether the MakeReady API `session` response includes a `role` or `isLeader` field. If yes, add the check. If not, match React behavior (auth-only gate).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel 12 default) |
| Config file | `phpunit.xml` |
| Quick run command | `php artisan test --filter=ContentTest` |
| Full suite command | `php artisan test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONT-01 | GET /groups/{id}/study/{id} returns 200 with lesson list | Feature/HTTP | `php artisan test --filter=ContentPagesTest` | ❌ Wave 0 |
| CONT-02 | GET /groups/{id}/lessons/{id}/1 returns 200 with LessonIsland mount point | Feature/HTTP | `php artisan test --filter=ContentPagesTest` | ❌ Wave 0 |
| CONT-03 | VideoPlayer island renders (SSR guard, no HLS in test env) | Feature/smoke | `php artisan test --filter=ContentPagesTest` | ❌ Wave 0 |
| CONT-04 | BulletTextInput renders in island (SSR — island div present) | Feature/smoke | `php artisan test --filter=ContentPagesTest` | ❌ Wave 0 |
| CONT-05 | GET /public/preview/{token}/lesson/{id}/1 returns 200 | Feature/HTTP | `php artisan test --filter=PreviewTest` | ❌ Wave 0 |
| CONT-06 | GET /public/preview/{token} returns 200 with study data | Feature/HTTP | `php artisan test --filter=PreviewTest` | ❌ Wave 0 |
| CONT-07 | GET /study returns 200 with code entry form | Feature/HTTP | `php artisan test --filter=ContentPagesTest` | ❌ Wave 0 |
| ADMN-01 | GET /admin returns 200 for auth member, 302 for guest | Feature/HTTP | `php artisan test --filter=AdminTest` | ❌ Wave 0 |
| INFR-03 | GET /nonexistent-route returns 404 with MakeReady HTML | Feature/HTTP | `php artisan test --filter=ErrorPagesTest` | ❌ Wave 0 |
| INFR-04 | 500 error view exists and renders without crashing | Feature/HTTP | `php artisan test --filter=ErrorPagesTest` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `php artisan test --filter=ContentPagesTest` or the relevant test class
- **Per wave merge:** `php artisan test` (full suite, all 133+ tests must stay green)
- **Phase gate:** Full suite green before cutover push to Railway

### Wave 0 Gaps
- [ ] `tests/Feature/ContentPagesTest.php` — covers CONT-01, CONT-02, CONT-03, CONT-04, CONT-07
- [ ] `tests/Feature/PreviewTest.php` — covers CONT-05, CONT-06
- [ ] `tests/Feature/AdminTest.php` — covers ADMN-01
- [ ] `tests/Feature/ErrorPagesTest.php` — covers INFR-03, INFR-04

**Test patterns to follow:** Copy `MemberPagesTest.php` structure — `Http::fake()` for API responses, assert status + assertSee() for key HTML. The FIFO Http::fake ordering issue (documented in STATE.md) is well-understood: register per-test fakes using helpers, not in setUp().

---

## Sources

### Primary (HIGH confidence)
- Project source code in `/Users/lukekeith/www/makeready/client/` — live codebase
- `archive/react-spa` git branch — original React implementation for all pages being migrated
- `tests/Feature/MemberPagesTest.php` — canonical test patterns for this project
- `app/Http/Controllers/GroupHomeController.php` — canonical controller pattern
- `resources/js/app.js` — island registration pattern
- `resources/js/components/domain/video-player/video-player.vue` — VideoPlayer implementation details
- `resources/js/components/primitive/bullet-text-input/bullet-text-input.vue` — BulletTextInput implementation

### Secondary (MEDIUM confidence)
- Laravel 12 documentation on custom error pages: `resources/views/errors/{code}.blade.php` convention is stable and well-documented
- Laravel exception handler `withExceptions()` API (Laravel 12 bootstrap/app.php style)

### Tertiary (LOW confidence — validate during planning)
- Bible API authentication requirement — not confirmed from source inspection alone
- Leader role field name on session member object — requires MCP API tool or archive inspection

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already installed and in use
- Architecture: HIGH — lesson island pattern is new but follows established island pattern exactly; React source fully reviewed
- API endpoints: HIGH — extracted directly from React archive source
- Pitfalls: HIGH — most are direct translations of React gotchas encountered in Phase 2/3
- Admin scope: HIGH — React admin page reviewed; it is intentionally minimal

**Research date:** 2026-03-18
**Valid until:** 2026-04-18 (stable Laravel + Vue patterns)
