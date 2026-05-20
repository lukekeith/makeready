# Phase 9: Members, Enrollments, Posts, Analytics, Profile - Research

**Researched:** 2026-03-20
**Domain:** Vue 3 + Pinia CRUD — members, enrollments, scheduled lessons, posts, analytics charts, leader profile
**Confidence:** HIGH for most areas; MEDIUM for member role/remove endpoints (see open questions)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MMBR-01 | Leader can view list of group members with name, avatar, role, and join date | `GET /api/groups/:id/members` confirmed from GroupActions.swift; response shape `{ success, members: [{ id, userId, groupId, role, name, avatarUrl, joinedAt }] }` |
| MMBR-02 | Leader can view a member's full profile (name, email, phone, groups) | `GET /api/members/:memberId/profile` confirmed from GroupActions.swift; response `{ success, data: MemberProfile }` with `id, firstName, lastName, phoneNumber, email, profilePicture, groups` |
| MMBR-03 | Leader can approve a pending membership request | `POST /api/groups/:groupId/join-requests/:requestId/approve` confirmed from GroupMembersPage.swift; empty body `{}` |
| MMBR-04 | Leader can reject a pending membership request | `GET /api/groups/:id/join-requests` confirmed; **reject endpoint NOT found in iPhone source** — needs validation (see Open Questions) |
| MMBR-05 | Leader can change a member's role (owner, admin, member) | **NOT found in any iPhone source** — role change endpoint unverified (see Open Questions) |
| MMBR-06 | Leader can remove a member from a group (with confirmation) | **NOT found in any iPhone source** — remove member endpoint unverified (see Open Questions) |
| ENRL-01 | Leader can view list of enrollments for a group, showing program name and date range | `GET /api/groups/:id/enrollments` confirmed from EnrollmentActions.swift; response `{ success, enrollments: [EnrollmentWithProgram] }` |
| ENRL-02 | Leader can create a new enrollment (select program, start date, enabled days, SMS time, timezone) | `POST /api/enrollments` confirmed; body: `{ groupId, studyProgramId, startDate (ISO8601), enabledDays: string[], smsTime?, timezone?, requireResponse }` |
| ENRL-03 | Leader can delete an enrollment (with confirmation showing lesson data impact) | `DELETE /api/enrollments/:id` confirmed; use `GET /api/enrollments/:id/unenroll-info` for pre-delete warning |
| ENRL-04 | Leader can cancel future lessons with no member data | `POST /api/enrollments/:id/cancel-future` confirmed from EnrollmentActions.swift; empty body `{}` |
| ENRL-05 | Enrollment detail shows the lesson schedule with dates and titles | `GET /api/enrollments/:id` confirmed; returns `{ success, enrollment: EnrollmentDetails }` with `lessonSchedules` array |
| SCHD-01 | Leader can view list of scheduled lessons within an enrollment | Covered by ENRL-05 (lessonSchedules from enrollment detail response) |
| SCHD-02 | Leader can edit a scheduled lesson title | `PATCH /api/enrollments/:id/schedules/:sid` confirmed; body: `{ title: string }` |
| SCHD-03 | Leader can add a new scheduled lesson to extend enrollment | `POST /api/enrollments/:id/schedules` confirmed; body: `{}` (empty) |
| SCHD-04 | Leader can delete a scheduled lesson | `DELETE /api/enrollments/:id/schedules/:sid` confirmed from EnrollmentActions.swift |
| POST-01 | Leader can view list of group posts with type, content preview, and date | `GET /api/groups/:id/posts?limit=N&cursor=X` confirmed; response `{ success, posts, nextCursor }` |
| POST-02 | Leader can create a post (type: announcement, poll, event, video) | `POST /api/groups/:id/posts` confirmed; body: `{ type, content, title?, pollOptions?, videoUrl?, eventDate?, eventLocation? }` |
| POST-03 | Announcement posts have title and content fields | Type `ANNOUNCEMENT` uses `content` (required) + `title` (optional) per GroupActions.swift |
| POST-04 | Poll posts have question and poll option fields | Type `POLL` uses `content` as the question + `pollOptions: string[]` array |
| POST-05 | Event posts have title, date, time, and location fields | Type `EVENT` uses `content`, `title?`, `eventDate` (ISO8601), `eventLocation?` |
| POST-06 | Video posts have title and video URL fields | Type `VIDEO` uses `content`, `title?`, `videoUrl` |
| ANLT-01 | Dashboard shows KPI cards (total groups, total members, active enrollments) | Derived data: groups from `GET /api/groups`, members from `GET /api/groups/:id/members` per group, enrollments from group list (use `memberCount` already in group response) |
| ANLT-02 | Dashboard shows activity heatmap (GitHub-style contribution calendar) | `GET /api/activity-logs/stats/heatmap` confirmed from HomeActions.swift; response `{ success, data: [{ day: 0-6, hour: 0-23, count }] }` — requires vue3-calendar-heatmap (NOT yet installed) |
| ANLT-03 | Dashboard shows weekly activity bar/area chart | `GET /api/activity-logs/stats` confirmed; response `{ success, data: [{ date: 'yyyy-MM-dd', count }] }` — requires apexcharts + vue3-apexcharts (NOT yet installed) |
| ANLT-04 | Dashboard shows calendar view of upcoming scheduled lessons across all groups | Derived from enrollment details for all groups (cascading load: groups → enrollments → enrollment details) — no dedicated endpoint, same approach as iPhone HomeActions.loadCalendarEvents() |
| PROF-01 | Leader can view and edit their profile (name, avatar) | `PATCH /api/members/:memberId` confirmed from API-AUDIT.md; fields: `firstName, lastName, gender, birthday` (camelCase per API contract) |
| PROF-02 | Leader can upload/change their profile picture from admin | `POST /api/members/:memberId/avatar` confirmed from API-AUDIT.md; multipart upload; response `{ success, data: { url } }` |
</phase_requirements>

---

## Summary

Phase 9 is the final and largest phase of the v2.0 milestone — 27 requirements across six feature areas, all scoped within the existing AdminIsland Vue app and AdminApiProxyController infrastructure built in Phases 5–8. The work divides cleanly into three tracks: (1) group-scoped CRUD — Members and Posts tab panels within the group detail view; (2) group-scoped enrollment management with the linked scheduled lessons sub-list; and (3) standalone sections — the Analytics dashboard and the Profile section — each needing their own stores, chart libraries, and section components.

The primary technical risk in this phase is the member management area (MMBR-04, MMBR-05, MMBR-06): the iPhone app source does NOT contain reject-request, change-role, or remove-member API calls. These features are specified in the requirements but have no confirmed endpoint patterns in the authoritative source. The safest path is to implement the endpoints with the most probable URL conventions (following the approve-request pattern already confirmed) and fail gracefully in the UI if they return 404. This is flagged as an open question with recommended fallback strategies.

The analytics dashboard requires installing two new npm packages — `apexcharts` + `vue3-apexcharts` (weekly bar chart) and `vue3-calendar-heatmap` (heatmap). ANLT-04 (calendar view) is the most expensive requirement in this phase: it requires a cascading load of enrollment details for every group, the same O(n_groups * n_enrollments_per_group) fetch strategy the iPhone HomeActions.loadCalendarEvents() uses. A reka-ui-based calendar grid with custom date-bucketed event display is the recommended approach for ANLT-04, avoiding a heavyweight external calendar library.

**Primary recommendation:** Build in this wave order: Wave 1 — Members tab + Enrollments tab (data-loading stores, tab panels, confirm dialogs); Wave 2 — Posts tab + Analytics dashboard (chart installs, KPI compute); Wave 3 — Profile section + shell completion (SHELL-02, SHELL-03, SHELL-07 cleanup).

---

## Standard Stack

### Core (all already installed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.30 | Component framework | Installed |
| Pinia | 3.0.4 | State management | Installed |
| Vue Router | 4.6.4 | Client-side routing | Installed |
| axios | 1.11.0 | HTTP client | Installed, CSRF configured |
| reka-ui | 2.9.2 | Headless UI (Tabs, Dialog, DatePicker) | Installed, used for enrollment date input |
| lucide-vue-next | 0.577.0 | Icons | Installed |
| histoire | 0.17.17 | Component stories | Installed |

### New Dependencies (must install before implementation)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| apexcharts | 5.10.4 | SVG chart engine | Confirmed npm version; ApexCharts team's official library |
| vue3-apexcharts | 1.11.1 | Vue 3 wrapper for ApexCharts | Official wrapper from ApexCharts team; Vue 3-native |
| vue3-calendar-heatmap | 2.0.5 | GitHub-style day/hour engagement heatmap | Purpose-built for this exact data shape `{ day, hour, count }` |

**Installation:**
```bash
npm install apexcharts vue3-apexcharts vue3-calendar-heatmap
```

**vue3-calendar-heatmap note (LOW confidence):** Last npm publish was 3 years ago. The package is stable for the `{ date, count }` input array the heatmap endpoint returns. However, the heatmap data from the API is `{ day: 0-6, hour: 0-23, count }` (day-of-week × hour grid), not a date-indexed calendar. This is a 7×24 grid, NOT the typical GitHub-style date calendar. This may require ApexCharts matrix heatmap or a custom SVG component instead. See Open Questions section for the resolution path.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| vue3-apexcharts | chart.js + vue-chartjs | ApexCharts is already researched and recommended; chart.js is fine but adds no benefit over the already-chosen ApexCharts |
| vue3-calendar-heatmap | Custom ApexCharts heatmap | If the day/hour shape is incompatible with vue3-calendar-heatmap, ApexCharts matrix heatmap is the fallback |
| reka-ui DatePicker for enrollments | Flatpickr, native `<input type="date">` | reka-ui DatePicker is already installed; native date input is the simplest fallback if reka-ui DatePicker has timezone issues |

---

## Architecture Patterns

### File Structure (Phase 9 additions)

```
resources/js/islands/admin-island/
├── sections/
│   ├── dashboard-section.vue      REWRITE (stub → full analytics)
│   ├── profile-section.vue        REWRITE (stub → full profile edit)
│   └── groups-section.vue         EXTEND (add tab panel content for Members, Enrollments, Posts)
├── stores/
│   ├── domain/
│   │   ├── members.domain.ts      NEW
│   │   ├── enrollments.domain.ts  NEW
│   │   ├── posts.domain.ts        NEW
│   │   └── analytics.domain.ts   NEW
│   └── ui/
│       ├── members-tab.ui.ts      NEW
│       ├── enrollments-tab.ui.ts  NEW
│       ├── posts-tab.ui.ts        NEW
│       ├── analytics.ui.ts        NEW
│       └── profile.ui.ts          NEW
└── components/
    └── admin-activity-chart/       (already exists from Phase 8)

resources/js/components/admin/
├── admin-table/                    (exists — reuse)
├── admin-form/                     (exists — reuse)
├── admin-confirm-dialog/           (exists — reuse)
├── admin-image-upload/             (exists — reuse)
├── admin-heatmap/
│   ├── admin-heatmap.vue          NEW
│   └── admin-heatmap.story.vue    NEW
├── admin-bar-chart/
│   ├── admin-bar-chart.vue        NEW
│   └── admin-bar-chart.story.vue  NEW
└── admin-calendar/
    ├── admin-calendar.vue          NEW (for ANLT-04)
    └── admin-calendar.story.vue   NEW

resources/css/components/admin/
├── admin-heatmap.scss             NEW
├── admin-bar-chart.scss           NEW
└── admin-calendar.scss            NEW
```

Also add to `router.ts`:
- No new routes needed — Groups section already has `/admin/groups/:id`; Dashboard section already at `/admin`; Profile at `/admin/profile`

---

### Pattern 1: Members Domain Store

**What:** `members.domain.ts` owns raw API calls for group members. Keyed by groupId to avoid cross-group data pollution.

**Confirmed endpoints from GroupActions.swift:**
- `GET /api/groups/:groupId/members` → `{ success, members: GroupMember[] }`
- `GET /api/members/:memberId/profile` → `{ success, data: MemberProfile }`
- `GET /api/groups/:groupId/join-requests` → `{ success, requests: JoinRequest[] }`
- `POST /api/groups/:groupId/join-requests/:requestId/approve` → `{ success }` empty body `{}`

**Unconfirmed endpoints (best-effort convention, validated against live API):**
- `DELETE /api/groups/:groupId/join-requests/:requestId` — probable reject endpoint
- `PATCH /api/groups/:groupId/members/:memberId` body `{ role: 'ADMIN' | 'MEMBER' }` — probable role change
- `DELETE /api/groups/:groupId/members/:memberId` — probable remove member

```typescript
// resources/js/islands/admin-island/stores/domain/members.domain.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import axios from 'axios'

export interface GroupMember {
  id: string
  userId: string
  groupId: string
  role: 'OWNER' | 'ADMIN' | 'MEMBER'
  name: string
  avatarUrl?: string
  joinedAt: string
}

export interface JoinRequest {
  id: string
  status: string
  message?: string
  createdAt: string
  member: {
    id: string
    firstName?: string
    lastName?: string
    avatarUrl?: string
  }
}

export interface MemberProfile {
  id: string
  firstName?: string
  lastName?: string
  phoneNumber: string
  email?: string
  profilePicture?: string
  googlePicture?: string
  groups: Array<{ id: string; name: string; coverImageUrl?: string; role: string; joinedAt: string }>
}

export const useMembersDomain = defineStore('members-domain', () => {
  const membersByGroup = ref<Record<string, GroupMember[]>>({})
  const requestsByGroup = ref<Record<string, JoinRequest[]>>({})
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadMembers(groupId: string): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/members`)
      membersByGroup.value[groupId] = res.data.members ?? []
    } catch (e: any) {
      error.value = e.response?.data?.error ?? 'Failed to load members'
    } finally {
      isLoading.value = false
    }
  }

  async function loadJoinRequests(groupId: string): Promise<void> {
    try {
      const res = await axios.get(`/admin/api/groups/${groupId}/join-requests`)
      requestsByGroup.value[groupId] = res.data.requests ?? []
    } catch (e: any) {
      error.value = e.response?.data?.error ?? 'Failed to load join requests'
    }
  }

  async function loadMemberProfile(memberId: string): Promise<MemberProfile> {
    const res = await axios.get(`/admin/api/members/${memberId}/profile`)
    return res.data.data
  }

  async function approveRequest(groupId: string, requestId: string): Promise<void> {
    await axios.post(`/admin/api/groups/${groupId}/join-requests/${requestId}/approve`, {})
    // Remove from requests list
    if (requestsByGroup.value[groupId]) {
      requestsByGroup.value[groupId] = requestsByGroup.value[groupId].filter(r => r.id !== requestId)
    }
    // Reload members to show newly approved member
    await loadMembers(groupId)
  }

  async function rejectRequest(groupId: string, requestId: string): Promise<void> {
    // Endpoint unconfirmed — try DELETE convention
    await axios.delete(`/admin/api/groups/${groupId}/join-requests/${requestId}`)
    if (requestsByGroup.value[groupId]) {
      requestsByGroup.value[groupId] = requestsByGroup.value[groupId].filter(r => r.id !== requestId)
    }
  }

  async function changeRole(groupId: string, memberId: string, role: 'ADMIN' | 'MEMBER'): Promise<void> {
    // Endpoint unconfirmed — try PATCH convention
    await axios.patch(`/admin/api/groups/${groupId}/members/${memberId}`, { role })
    if (membersByGroup.value[groupId]) {
      const idx = membersByGroup.value[groupId].findIndex(m => m.id === memberId)
      if (idx >= 0) membersByGroup.value[groupId][idx] = { ...membersByGroup.value[groupId][idx], role }
    }
  }

  async function removeMember(groupId: string, memberId: string): Promise<void> {
    // Endpoint unconfirmed — try DELETE convention
    await axios.delete(`/admin/api/groups/${groupId}/members/${memberId}`)
    if (membersByGroup.value[groupId]) {
      membersByGroup.value[groupId] = membersByGroup.value[groupId].filter(m => m.id !== memberId)
    }
  }

  return {
    membersByGroup, requestsByGroup, isLoading, error,
    loadMembers, loadJoinRequests, loadMemberProfile,
    approveRequest, rejectRequest, changeRole, removeMember
  }
})
```

---

### Pattern 2: Enrollments Domain Store

**Confirmed endpoints from EnrollmentActions.swift:**

```typescript
// resources/js/islands/admin-island/stores/domain/enrollments.domain.ts
export interface Enrollment {
  id: string
  groupId: string
  studyProgramId: string
  startDate: string   // ISO8601
  endDate: string
  enabledDays: string  // JSON array string e.g. '["MON","WED","FRI"]'
  smsTime?: string
  timezone?: string
  requireResponse?: boolean
  createdAt: string
  updatedAt: string
}

export interface EnrollmentWithProgram extends Enrollment {
  studyProgram?: {
    id: string
    name: string
    coverImageUrl?: string
  }
}

export interface LessonSchedule {
  id: string
  enrollmentId: string
  scheduledDate: string  // ISO8601
  title?: string
  lesson?: {
    dayNumber: number
    title: string
  }
}

export interface EnrollmentDetails extends Enrollment {
  studyProgram?: { id: string; name: string; coverImageUrl?: string }
  lessonSchedules: LessonSchedule[]
}

export interface UnenrollInfo {
  totalLessons: number
  lessonsWithData: number
  cleanLessons: number
}

export interface CreateEnrollmentPayload {
  groupId: string
  studyProgramId: string
  startDate: string        // ISO8601 with time
  enabledDays: string[]    // e.g. ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT']
  smsTime?: string
  timezone?: string
  requireResponse?: boolean
}

// Key API actions:
// GET /api/groups/:groupId/enrollments → { success, enrollments: EnrollmentWithProgram[] }
// POST /api/enrollments → { success, enrollment: Enrollment }
// DELETE /api/enrollments/:id → { success }
// GET /api/enrollments/:id → { success, enrollment: EnrollmentDetails }
// GET /api/enrollments/:id/unenroll-info → { success, data: UnenrollInfo }
// POST /api/enrollments/:id/cancel-future → { success }
// POST /api/enrollments/:id/schedules → { success } (empty body)
// PATCH /api/enrollments/:id/schedules/:sid → { success } body: { title }
// DELETE /api/enrollments/:id/schedules/:sid → { success }
```

**Critical format note:** `startDate` must be ISO8601 with full datetime + fractional seconds, matching Swift's `ISO8601DateFormatter` with `.withFractionalSeconds`. Use `new Date(dateValue).toISOString()` which produces `2025-09-01T00:00:00.000Z`.

**enabledDays format:** The API body takes an array of strings, e.g. `["MON", "WED", "FRI"]`. The iPhone uses `['SUN','MON','TUE','WED','THU','FRI','SAT']` abbreviations. The stored `enabledDays` field on the Enrollment model is a JSON array string — deserialize with `JSON.parse()` when displaying.

---

### Pattern 3: Posts Domain Store

**Confirmed endpoints from GroupActions.swift:**

```typescript
// resources/js/islands/admin-island/stores/domain/posts.domain.ts
export type PostType = 'ANNOUNCEMENT' | 'POLL' | 'EVENT' | 'VIDEO' | 'WELCOME'

export interface GroupPost {
  id: string
  groupId: string
  authorId?: string
  authorName: string
  authorAvatarUrl?: string
  type: PostType
  content: string
  title?: string
  pollOptions?: Array<{ id: string; text: string; voteCount: number; hasVoted: boolean }>
  videoUrl?: string
  eventDate?: string
  eventLocation?: string
  eventTitle?: string
  viewCount?: number
  shareCount?: number
  createdAt: string
  updatedAt: string
}

export interface CreatePostPayload {
  type: PostType
  content: string
  title?: string
  pollOptions?: string[]   // array of option text strings for POLL type
  videoUrl?: string        // for VIDEO type
  eventDate?: string       // ISO8601 for EVENT type
  eventLocation?: string   // for EVENT type
}

// API:
// GET /api/groups/:id/posts?limit=20&cursor=X → { success, posts, nextCursor }
// POST /api/groups/:id/posts → { success, post: GroupPost }
// DELETE endpoint: UNCONFIRMED (not in any iPhone source)
```

**Post delete endpoint:** Not found in GroupActions.swift or any iPhone page source. POST-01 through POST-06 do not include delete, so this is not a blocker. Do not implement post delete in Phase 9.

---

### Pattern 4: Analytics Domain Store + Data Loading Strategy

**Confirmed endpoints from HomeActions.swift:**
- `GET /api/activity-logs/stats/heatmap` → `{ success, data: HeatmapBucket[] }` where `HeatmapBucket = { day: 0-6, hour: 0-23, count: number }`
- `GET /api/activity-logs/stats` → `{ success, data: DayActivityCount[] }` where `DayActivityCount = { date: 'yyyy-MM-dd', count: number }`

**KPI computation (ANLT-01):** Groups are already loaded in `groups.domain.ts`. KPI cards compute from:
- `totalGroups`: `groups.value.length`
- `totalMembers`: sum of unique `memberCount` fields across groups (already in `UserGroup.memberCount` per GroupModels.swift — confirmed the field exists in list response)
- `activeEnrollments`: load enrollments per group and count where `endDate >= today`

**Calendar loading strategy (ANLT-04):** Following the iPhone HomeActions.loadCalendarEvents() pattern exactly:
1. Load all groups (already cached in `groups.domain.ts`)
2. For each group, load enrollments (`GET /api/groups/:id/enrollments`)
3. For each enrollment, load details (`GET /api/enrollments/:id`)
4. Collect all `lessonSchedules` where `scheduledDate >= today`
5. Group by date string `yyyy-MM-dd`

This is N+1 fetching by design — do NOT try to optimize with a single endpoint that doesn't exist. Parallelize with `Promise.all()`.

**Heatmap data shape clarification:** The heatmap endpoint returns a 7×24 grid (day of week × hour of day). This is NOT a date-indexed calendar. It shows "what hour/day-of-week do members complete lessons?" Use a custom 7×24 SVG grid or an ApexCharts matrix heatmap, NOT vue3-calendar-heatmap (which expects date-indexed data). See Don't Hand-Roll section.

---

### Pattern 5: Profile Store and Section

**Confirmed endpoints from API-AUDIT.md:**
- `PATCH /api/members/:memberId` — profile update
- `POST /api/members/:memberId/avatar` — avatar upload (multipart)
- Response for avatar: `{ success, data: { url: string } }` — use `res.data.data.url`

**Request body for PATCH:** Must use camelCase field names: `{ firstName, lastName, gender, birthday }`. API-AUDIT.md confirms snake_case fails silently. Birthday format: ISO string via `new Date(birthdayDate).toISOString()`.

**Profile store needs:**
- Load current profile from middleware-provided member data (available as Blade props on `AdminIsland`)
- Expose form fields: firstName, lastName (gender/birthday are optional for admin context)
- Emit save → call PATCH → update local state
- Avatar upload: reuse `AdminImageUpload` component pattern from Groups/Programs phases

**memberId source:** The admin island already receives `member` in its Blade-passed props (confirmed from Phase 5 architecture). Use `props.member.id` for the API calls.

---

### Pattern 6: EnabledDays Checkbox UI (Enrollment Create Form)

The enrollment create form has a unique UI requirement — a row of 7 day checkboxes (Sun-Sat). This does not fit the generic `AdminForm` component's field types. Two approaches:

**Recommended:** Extend `AdminForm` with a new field type `'days'` that renders 7 checkboxes. This keeps the form pattern consistent.

**Alternative:** Render the enrollment create form inline in `enrollments-tab.vue` section component without delegating to `AdminForm`, since the form is unique enough to warrant custom treatment.

The day abbreviations expected by the API (from EnrollmentActions.swift `enabledDays` parameter): `'SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'`.

---

### Pattern 7: vue3-apexcharts Registration

```typescript
// In admin-island.vue onMounted or plugin registration — register globally once
import VueApexCharts from 'vue3-apexcharts'

// In admin-island.vue setup or at app level:
app.use(VueApexCharts)
// OR use component directly:
import ApexChart from 'vue3-apexcharts'
```

Weekly bar chart series shape:
```typescript
// Source: api response DayActivityCount[]
const series = [{
  name: 'Activity',
  data: weeklyData.map(d => d.count)
}]
const categories = weeklyData.map(d => d.date)  // 'yyyy-MM-dd'
```

---

### Anti-Patterns to Avoid

- **Polling the heatmap endpoint repeatedly:** Load once on dashboard mount, cache in analytics store. Do not refetch on every tab switch.
- **Separate axios calls per member for KPI:** `memberCount` is already in the group list response — use it directly, no per-group member API call needed for ANLT-01.
- **Nested router views for enrollment detail:** ENRL-05 (enrollment detail with lesson schedule) should be rendered as an in-section expandable panel, not a new router view. Adding a new route (`/admin/groups/:id/enrollments/:eid`) is unnecessary complexity.
- **Blocking ANLT-04 calendar on sequential fetches:** Use `Promise.all()` for the enrollment detail cascade, not sequential awaits.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Weekly bar chart | Custom SVG bar chart | `vue3-apexcharts` + `apexcharts` | Edge cases: responsive resize, tooltip alignment, dark theme colors |
| Day/hour heatmap grid | Custom HTML table-based heatmap | ApexCharts matrix heatmap (`type: 'heatmap'`) OR custom SVG via computed 7x24 grid | vue3-calendar-heatmap is NOT the right fit for day×hour data |
| Date picker for enrollment start date | `<input type="date">` (timezone issues) | `reka-ui DatePicker` (already installed) | Native date input returns local date string with timezone ambiguity; reka-ui DatePicker provides structured Date object |
| Tab state for Members/Enrollments/Posts | Separate Vue Router routes | Active tab `ref` in `group-detail.ui.ts` + reka-ui Tabs | Routing to `/admin/groups/:id/members` would require new routes, breaks back navigation UX, and is inconsistent with Phase 6 tab chrome already built |
| Delete confirmation for all entities | `window.confirm()` | `AdminConfirmDialog` component (already built) | Consistent, styled, themeable, keyboard accessible |
| Form reset between create/edit | Manual field clearing | `:key="editingId ?? 'create'"` on `AdminForm` | Forces component remount, proven pattern from Phase 6 |

---

## Common Pitfalls

### Pitfall 1: enabledDays Stored as JSON String

**What goes wrong:** The `Enrollment.enabledDays` field returned from `GET /api/enrollments/:id` is a JSON array string `'["MON","WED","FRI"]'`, not a parsed array. Passing it directly to checkbox v-model fails.

**Why it happens:** The API stores it as a serialized string in the database and returns it as-is.

**How to avoid:** Always `JSON.parse(enrollment.enabledDays)` before rendering. When submitting the create payload, send a real JS array — axios will serialize it correctly.

**Warning signs:** Checkboxes show no pre-selected values on edit; all days appear unselected.

---

### Pitfall 2: startDate Timezone Loss

**What goes wrong:** The enrollment start date the leader selects in the browser (e.g., "Sept 1 2025") is submitted as midnight UTC, which may appear as August 31 in the leader's timezone.

**Why it happens:** reka-ui DatePicker returns a CalendarDate or Date object in local time. `toISOString()` converts to UTC, which can roll back a day for UTC-offset timezones.

**How to avoid:** For start date, the time component is irrelevant — the API uses `startDate` to compute the first lesson day. Submit `startDate` as `YYYY-MM-DDT00:00:00.000Z` (midnight UTC) regardless of leader timezone. The leader's `timezone` field in the enrollment payload governs SMS delivery time, not the start date.

**Warning signs:** Leader selects Sept 1, enrollment shows Aug 31 scheduled lessons.

---

### Pitfall 3: Member Tab Reload on Every Tab Switch

**What goes wrong:** Every time the leader switches to the Members tab in the group detail, the store re-fetches all members and requests from the API, causing a loading flash and unnecessary network calls.

**Why it happens:** If `loadMembers(groupId)` is called in the Members tab `onMounted`, it fires every time the component re-mounts due to reka-ui Tabs unmounting inactive panels.

**How to avoid:** Cache in the domain store. Add a `loadedGroupIds` set to `members.domain.ts` and skip the API call if already loaded:
```typescript
const loadedGroupIds = ref(new Set<string>())
async function loadMembers(groupId: string, force = false): Promise<void> {
  if (!force && loadedGroupIds.value.has(groupId)) return
  // ... fetch ...
  loadedGroupIds.value.add(groupId)
}
```

Invalidate on approve/reject/remove by calling `loadMembers(groupId, true)`.

**Warning signs:** Network tab shows repeated GET /admin/api/groups/:id/members on every tab click.

---

### Pitfall 4: reka-ui Tabs Unmount Inactive Panels

**What goes wrong:** Analytics charts render, user switches tab, switches back — chart is blank or shows wrong size.

**Why it happens:** reka-ui Tabs by default unmounts the inactive `TabsContent`. ApexCharts and vue3-apexcharts lose their DOM container reference. When remounted, the chart renders at 0px width because the container has not been painted yet.

**How to avoid:** Add `force-mount` to the `TabsContent` of chart-heavy panels, or call `chart.updateOptions({ chart: { width: '100%' } })` in the chart component's `onMounted`. For the analytics dashboard (not a tabbed panel), this is not an issue — the dashboard section is a full-page view.

---

### Pitfall 5: Unconfirmed Member Endpoints Returning 404

**What goes wrong:** Role change or remove member calls return 404. The UI shows a generic error and the member list becomes stale.

**Why it happens:** These endpoints do not appear in the iPhone app source — they may not exist or may use different URL conventions.

**How to avoid:** Wrap these calls in try/catch. On 404 response, surface a specific message: "This action is not available." Log the attempted URL for debugging. After a 404, re-fetch the member list to ensure the UI reflects the actual server state.

**Warning signs:** Console error `404 /admin/api/groups/:id/members/:id`. The member list is unchanged after the attempted action.

---

### Pitfall 6: Post Pagination Cursor Ignored

**What goes wrong:** The posts list only shows 20 posts even if the group has 100+. Leader cannot see older posts.

**Why it happens:** `GET /api/groups/:id/posts?limit=20` returns a `nextCursor` for pagination. If the store does not implement "load more," posts beyond the first page are invisible.

**How to avoid:** Store the `nextCursor` in `posts.domain.ts`. Render a "Load More" button in the posts tab that calls `loadPosts(groupId, cursor: nextCursor.value)` and appends results. Clear `nextCursor` when `null` is returned (end of feed).

---

### Pitfall 7: Analytics Calendar O(N) Waterfall

**What goes wrong:** Dashboard loads groups (1 call), then loads enrollments for each group (N calls), then loads enrollment details for each enrollment (N×M calls). On a large account, this is dozens of sequential requests causing a 10+ second load.

**Why it happens:** The cascade is serial if not parallelized. The iPhone app uses Swift's `withTaskGroup` for parallel fetching, which is not the default behavior in JS `async/await` chains.

**How to avoid:** Use `Promise.all()` for each fan-out:
```typescript
// Load enrollments for all groups in parallel
const enrollmentsByGroup = await Promise.all(
  groups.map(g => axios.get(`/admin/api/groups/${g.id}/enrollments`))
)
// Load details for all enrollments in parallel
const allEnrollments = enrollmentsByGroup.flatMap(r => r.data.enrollments ?? [])
const details = await Promise.all(
  allEnrollments.map(e => axios.get(`/admin/api/enrollments/${e.id}`))
)
```

**Warning signs:** Network tab shows serial waterfall. Dashboard takes 15+ seconds to show calendar on a large account.

---

## Code Examples

### Enrollment Create Payload

```typescript
// Source: EnrollmentActions.swift createEnrollment()
// Correct shape for POST /api/enrollments
const payload = {
  groupId: 'grp-123',
  studyProgramId: 'prog-456',
  startDate: new Date(selectedDate).toISOString(),  // "2025-09-01T00:00:00.000Z"
  enabledDays: ['MON', 'WED', 'FRI'],               // array, not JSON string
  smsTime: '08:00',                                 // optional HH:mm string
  timezone: 'America/New_York',                     // optional IANA timezone
  requireResponse: false
}
```

### Approve Join Request

```typescript
// Source: GroupMembersPage.swift approveRequest()
// POST /api/groups/:groupId/join-requests/:requestId/approve
await axios.post(`/admin/api/groups/${groupId}/join-requests/${requestId}/approve`, {})
// Response: { success: true }
```

### Create Post (type-conditional payload)

```typescript
// Source: GroupActions.swift createPost()
// POST /api/groups/:groupId/posts
const payload: Record<string, any> = {
  type: postType,    // 'ANNOUNCEMENT' | 'POLL' | 'EVENT' | 'VIDEO'
  content: content   // required for all types
}
if (title) payload.title = title
if (postType === 'POLL' && pollOptions.length) payload.pollOptions = pollOptions  // string[]
if (postType === 'VIDEO' && videoUrl) payload.videoUrl = videoUrl
if (postType === 'EVENT') {
  if (eventDate) payload.eventDate = new Date(eventDate).toISOString()
  if (eventLocation) payload.eventLocation = eventLocation
}
```

### ApexCharts Weekly Bar Chart (vue3-apexcharts)

```vue
<!-- resources/js/components/admin/admin-bar-chart/admin-bar-chart.vue -->
<script setup lang="ts">
import { computed } from 'vue'
import ApexChart from 'vue3-apexcharts'

const props = defineProps<{
  data: Array<{ date: string; count: number }>
}>()

const series = computed(() => [{
  name: 'Activity',
  data: props.data.map(d => d.count)
}])

const options = computed(() => ({
  chart: {
    type: 'bar',
    background: 'transparent',
    toolbar: { show: false },
  },
  xaxis: {
    categories: props.data.map(d => d.date),
    labels: { style: { colors: 'rgba(255,255,255,0.5)' } }
  },
  yaxis: {
    labels: { style: { colors: 'rgba(255,255,255,0.5)' } }
  },
  colors: ['#6c47ff'],
  plotOptions: { bar: { borderRadius: 4 } },
  theme: { mode: 'dark' }
}))
</script>
<template>
  <ApexChart type="bar" :series="series" :options="options" height="200" />
</template>
```

### Heatmap: Custom 7x24 Grid (ApexCharts matrix approach)

```typescript
// Source: HomeActions.swift + HeatmapBucket model
// The API returns { day: 0-6, hour: 0-23, count: number }
// Transform for ApexCharts heatmap:

function buildHeatmapSeries(buckets: HeatmapBucket[]) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  return days.map((dayName, dayIdx) => ({
    name: dayName,
    data: Array.from({ length: 24 }, (_, hour) => {
      const bucket = buckets.find(b => b.day === dayIdx && b.hour === hour)
      return { x: `${hour}:00`, y: bucket?.count ?? 0 }
    })
  }))
}
```

### reka-ui DatePicker for Enrollment Start Date

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { DatePickerRoot, DatePickerTrigger, DatePickerContent, DatePickerGrid, DatePickerCell } from 'reka-ui'
// CalendarDate from @internationalized/date (peer dep of reka-ui)
import { CalendarDate, today, getLocalTimeZone } from '@internationalized/date'

const startDate = ref(today(getLocalTimeZone()))

function toISOString(calDate: CalendarDate): string {
  return new Date(calDate.year, calDate.month - 1, calDate.day).toISOString()
}
</script>
```

### Profile Update

```typescript
// Source: API-AUDIT.md — confirmed camelCase required
// PATCH /api/members/:memberId
await axios.patch(`/admin/api/members/${memberId}`, {
  firstName: form.firstName,
  lastName: form.lastName,
  // Do NOT send snake_case — API ignores first_name, last_name
})
```

### Avatar Upload Response Extraction

```typescript
// Source: API-AUDIT.md — response shape is { success, data: { url } }
const res = await axios.post(`/admin/api/members/${memberId}/avatar`, formData)
const avatarUrl = res.data.data.url   // NOT res.data.avatarUrl
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate Pinia per island | Single AdminIsland shared Pinia | Phase 5 | All new domain stores share context with groups/programs stores |
| window.confirm() for deletes | AdminConfirmDialog (reka-ui Dialog) | Phase 6 | All destructive confirmations use the consistent component |
| Stubs for Members/Enrollments/Posts tabs | Real tab panel content | Phase 9 (this phase) | Group detail becomes fully functional |
| Stub dashboard-section.vue | Real analytics with charts | Phase 9 (this phase) | Dashboard becomes the admin home page |
| Stub profile-section.vue | Real profile edit form | Phase 9 (this phase) | Leaders can update their profile from web |

---

## Open Questions

### 1. CRITICAL: Reject Request Endpoint (MMBR-04)

**What we know:** The iPhone app source does not contain a "reject join request" API call. The approve call is `POST /api/groups/:groupId/join-requests/:requestId/approve`. No reject equivalent found.

**What's unclear:** Whether the endpoint is `DELETE /api/groups/:groupId/join-requests/:requestId`, `POST .../reject`, or not exposed at all.

**Recommendation:** Implement as `DELETE /api/groups/:groupId/join-requests/:requestId` (REST convention for removing a resource). If it returns 404 or 405, surface "Reject is not available at this time" and hide the reject button. Do not block the wave on this — approve is confirmed and higher value.

---

### 2. CRITICAL: Role Change and Remove Member Endpoints (MMBR-05, MMBR-06)

**What we know:** No PATCH or DELETE on `/api/groups/:id/members/:id` appears anywhere in the iPhone source. The GroupMember model has a `role` field. The iPhone app displays member role but has no UI for changing it or removing members.

**What's unclear:** Whether these endpoints exist on the API server but are simply unused by the iPhone app, or whether they do not exist at all.

**Recommendation:**
1. Implement with standard REST conventions: `PATCH /api/groups/:groupId/members/:memberId` body `{ role }` and `DELETE /api/groups/:groupId/members/:memberId`.
2. Wrap both in a dedicated feature-flag check: if the first PATCH returns 404, hide the role change dropdown for the current session and log a warning.
3. Do not block the phase on these — implement MMBR-01 through MMBR-03 (list, profile view, approve) first as they are fully confirmed. Add MMBR-05 and MMBR-06 as best-effort.

---

### 3. MEDIUM: Heatmap Component Choice (ANLT-02)

**What we know:** The API returns `{ day: 0-6, hour: 0-23, count }` — a day-of-week × hour-of-day grid. `vue3-calendar-heatmap` expects `{ date: 'YYYY-MM-DD', count }` calendar date data.

**What's unclear:** Whether ApexCharts matrix heatmap produces acceptable visual output within the dark admin theme.

**Recommendation:** Use ApexCharts `type: 'heatmap'` with the 7×24 series transform shown in Code Examples. This avoids installing `vue3-calendar-heatmap` and uses the already-needed `apexcharts` package. If the visual result is unsatisfactory, a custom 7×24 CSS grid is 50 lines of template code.

---

### 4. LOW: Active Enrollment Count for ANLT-01

**What we know:** The KPI card needs "active enrollments." `GET /api/groups/:id/enrollments` returns `EnrollmentWithProgram[]` which includes `endDate`. An enrollment is "active" if `endDate >= today`.

**What's unclear:** Whether there is a simpler dedicated endpoint or whether enrollment count must be computed by loading all enrollments.

**Recommendation:** Load enrollments for all groups using the same cascade as the calendar (ANLT-04). Compute `activeEnrollments = allEnrollments.filter(e => new Date(e.endDate) >= new Date())`. Reuse the same `Promise.all()` fetch for both KPI and calendar data — do not make the same API calls twice.

---

### 5. LOW: Post Delete Endpoint (POST-01..06 scope)

**What we know:** POST-01 through POST-06 do not include post delete. The delete endpoint is not in the iPhone source.

**What's unclear:** Whether delete exists on the API.

**Recommendation:** Do not implement post delete in Phase 9. The requirements do not include it. Document as a known gap in the posts tab.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel feature tests) |
| Config file | `phpunit.xml` |
| Quick run command | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php` |
| Full suite command | `php artisan test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MMBR-01 | GET /admin/api/groups/:id/members proxied to external API | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_members_list_proxy` | ❌ Wave 0 |
| MMBR-02 | GET /admin/api/members/:id/profile proxied correctly | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_member_profile_proxy` | ❌ Wave 0 |
| MMBR-03 | POST /admin/api/groups/:id/join-requests/:rid/approve proxied with empty body | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_approve_request_proxy` | ❌ Wave 0 |
| ENRL-01 | GET /admin/api/groups/:id/enrollments proxied | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_enrollments_list_proxy` | ❌ Wave 0 |
| ENRL-02 | POST /admin/api/enrollments proxied with correct shape (groupId, studyProgramId, startDate, enabledDays) | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_create_enrollment_proxy` | ❌ Wave 0 |
| ENRL-03 | DELETE /admin/api/enrollments/:id proxied | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_delete_enrollment_proxy` | ❌ Wave 0 |
| ENRL-04 | POST /admin/api/enrollments/:id/cancel-future proxied with empty body | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_cancel_future_proxy` | ❌ Wave 0 |
| ENRL-05 | GET /admin/api/enrollments/:id proxied and returns lessonSchedules | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_enrollment_detail_proxy` | ❌ Wave 0 |
| SCHD-02 | PATCH /admin/api/enrollments/:id/schedules/:sid proxied with { title } | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_update_schedule_proxy` | ❌ Wave 0 |
| SCHD-03 | POST /admin/api/enrollments/:id/schedules proxied with empty body | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_add_schedule_proxy` | ❌ Wave 0 |
| SCHD-04 | DELETE /admin/api/enrollments/:id/schedules/:sid proxied | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_delete_schedule_proxy` | ❌ Wave 0 |
| POST-01 | GET /admin/api/groups/:id/posts?limit=20 proxied | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_posts_list_proxy` | ❌ Wave 0 |
| POST-02 | POST /admin/api/groups/:id/posts proxied with correct shape | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_create_post_proxy` | ❌ Wave 0 |
| ANLT-01 | GET /admin/api/groups and GET /admin/api/groups/:id/members used for KPI | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_analytics_kpi_endpoints` | ❌ Wave 0 |
| ANLT-02 | GET /admin/api/activity-logs/stats/heatmap proxied | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_heatmap_proxy` | ❌ Wave 0 |
| ANLT-03 | GET /admin/api/activity-logs/stats proxied | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_weekly_stats_proxy` | ❌ Wave 0 |
| PROF-01 | PATCH /admin/api/members/:id proxied with camelCase fields | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_profile_update_proxy` | ❌ Wave 0 |
| PROF-02 | POST /admin/api/members/:id/avatar proxied as multipart | integration | `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php --filter test_avatar_upload_proxy` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `php artisan test tests/Feature/MembersEnrollmentsAdminTest.php`
- **Per wave merge:** `php artisan test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/Feature/MembersEnrollmentsAdminTest.php` — covers all 17 proxy tests above
  - Follows `GroupsAdminTest.php` pattern: `Http::fake()` to mock external API responses, test Laravel proxy routing and JSON forwarding
  - Uses `fakeSession()` helper consistent with existing admin tests
  - MMBR-04/05/06 proxy tests: defer until Open Question resolution; mark with `@group unconfirmed` tag

*(No framework install gaps — PHPUnit installed and running. apexcharts + vue3-apexcharts + vue3-calendar-heatmap need `npm install` before Vue components can be built.)*

---

## Sources

### Primary (HIGH confidence)

- `/iphone/MakeReady/State/Actions/GroupActions.swift` — members endpoints: GET /api/groups/:id/members, GET /api/members/:id/profile; posts endpoints: GET + POST /api/groups/:id/posts; confirm member count in list response
- `/iphone/MakeReady/Pages/Manage/Group/Member/GroupMembersPage.swift` — approve request endpoint confirmed: POST /api/groups/:id/join-requests/:rid/approve; join requests endpoint: GET /api/groups/:id/join-requests; confirms NO reject/role-change/remove endpoints in iPhone source
- `/iphone/MakeReady/Pages/Manage/Group/Models/GroupModels.swift` — GroupMember model confirms `role: GroupRole`, `joinedAt: Date`; `UserGroup.memberCount: Int` confirms memberCount in group list response; `PostType` enum confirms ANNOUNCEMENT, POLL, EVENT, VIDEO, WELCOME
- `/iphone/MakeReady/State/Actions/EnrollmentActions.swift` — all enrollment endpoints confirmed with exact request shapes; `Enrollment` struct confirms `enabledDays: String` (JSON string, not array)
- `/iphone/MakeReady/State/Actions/HomeActions.swift` — heatmap endpoint confirmed; weekly stats endpoint confirmed; `HeatmapBucket { day: Int, hour: Int, count: Int }` confirms day×hour grid shape (NOT date-indexed)
- `/client/.planning/API-AUDIT.md` — profile update: camelCase required; avatar upload response: `{ success, data: { url } }`
- `/client/resources/js/islands/admin-island/router.ts` — current routes; confirms no enrollment sub-routes needed
- `/client/resources/js/islands/admin-island/stores/domain/groups.domain.ts` — groups domain pattern to follow for new domain stores
- npm registry — `apexcharts@5.10.4`, `vue3-apexcharts@1.11.1`, `vue3-calendar-heatmap@2.0.5` versions confirmed

### Secondary (MEDIUM confidence)

- `.planning/research/SUMMARY.md` — apexcharts + vue3-apexcharts + vue3-calendar-heatmap stack recommendation
- `.planning/research/FEATURES.md` — API surface table; post delete endpoint flagged as unconfirmed
- `.planning/phases/06-groups-crud/06-RESEARCH.md` — AdminForm, AdminTable, AdminConfirmDialog, AdminImageUpload patterns to reuse
- reka-ui 2.9.2 package.json — DatePicker confirmed installed; import from `'reka-ui'`

### Tertiary (LOW confidence)

- Member role change and remove endpoints — inferred from REST conventions, not confirmed from any source
- Reject join request endpoint — inferred from REST conventions, not confirmed from any source
- Post delete endpoint — not found in any source; assumed absent

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Members list + profile + approve | HIGH | All three confirmed from GroupActions.swift and GroupMembersPage.swift |
| Members reject/role/remove | LOW | Not found in any iPhone source; best-effort REST convention |
| Enrollments CRUD | HIGH | All endpoints confirmed from EnrollmentActions.swift with exact request shapes |
| Scheduled lessons CRUD | HIGH | All endpoints confirmed from EnrollmentActions.swift |
| Posts list + create | HIGH | Confirmed from GroupActions.swift and GroupModels.swift |
| Post delete | LOW | Not found in any source |
| Analytics heatmap + weekly stats | HIGH | Endpoints confirmed from HomeActions.swift; data shapes confirmed from Swift model types |
| Analytics calendar (ANLT-04) | HIGH | Cascade load strategy confirmed from HomeActions.loadCalendarEvents() |
| Heatmap component choice | MEDIUM | vue3-calendar-heatmap incompatible with day×hour data; ApexCharts matrix alternative recommended but not prototyped |
| Profile edit | HIGH | PATCH and avatar upload endpoints confirmed from API-AUDIT.md; camelCase requirement confirmed |
| New npm packages (apexcharts) | HIGH | Versions confirmed from npm registry |

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (API stable; stack stable; member endpoints LOW confidence expire immediately if discovered to be wrong)
