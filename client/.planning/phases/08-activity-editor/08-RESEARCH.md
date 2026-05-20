# Phase 8: Activity Editor - Research

**Researched:** 2026-03-20
**Domain:** Vue 3 + Pinia CRUD — activity management nested within lessons, with typed content fields, read blocks, and scripture source references
**Confidence:** HIGH — all API shapes confirmed directly from iPhone source (`ProgramActions.swift`, `StudyModels.swift`)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ACTV-01 | Leader can view list of activities within a lesson, showing type and title | Activities nested in `GET /api/programs/:id` response via `lesson.activities[]`; each has `id`, `activityType`, `title`, `orderNumber` |
| ACTV-02 | Leader can add a new activity (select type: READ, VIDEO, USER_INPUT, PRAYER, REFLECTION, SOAP) | `POST /api/programs/:id/lessons/:lid/activities` with `{ activityType, title }`; response `{ success, activity }` |
| ACTV-03 | Leader can edit activity title and help panel (title, description, icon, toggle enabled) | `PATCH /api/activities/:id` with `{ title?, readContent?, isHelpEnabled?, helpTitle?, helpDescription?, helpIcon?, status: "COMPLETE" }`; response `{ success, activity }` |
| ACTV-04 | Leader can edit READ activity content (plain text and/or read blocks) | `readContent` is plain/markdown string via `PATCH /api/activities/:id`; read blocks managed separately via `/read-blocks` sub-resource |
| ACTV-05 | Leader can add/remove scripture source references on an activity | `POST /api/activities/:id/source-references` with passage fields; delete is NOT confirmed — see Open Questions |
| ACTV-06 | Leader can manage read blocks within an activity (create, edit, delete, reorder) | Four endpoints confirmed: POST/PATCH/DELETE/reorder on `/api/activities/:id/read-blocks` and `/api/activities/:id/read-blocks/:bid` and `PATCH /api/activities/:id/read-blocks/reorder` |
| ACTV-07 | Leader can delete an activity (with confirmation) | `DELETE /api/activities/:id`; response `{ success }` |
| ACTV-08 | Leader can reorder activities via drag-and-drop | `POST /api/programs/:id/lessons/:lid/reorder-activities` with `{ activityOrder: [id, ...] }`; response `{ success, activities: [...] }` |
| ACTV-09 | Leader can clear/reset an activity's content | `POST /api/activities/:id/reset`; response `{ success, activity }` with activity reset to pending state |
</phase_requirements>

---

## Summary

Phase 8 adds the Activity Editor to the existing Program Detail view — the deepest nesting level in the admin panel (Program → Lesson → Activities). Activities are managed inline within the Lessons tab of `programs-section.vue`. The critical blocker from STATE.md is fully resolved: this research confirms every activity API endpoint shape directly from `ProgramActions.swift` and `StudyModels.swift` in the iPhone source.

The key insight is that activity content is **not rich text**. All content fields are plain strings (or null). `readContent` is a plain-text/markdown string stored on the activity itself. `ActivityReadBlock.content` is also a plain string. No Tiptap or rich text editor is needed for MVP. Simple `<textarea>` fields are sufficient and correct.

The second key insight is that the `PATCH /api/activities/:id` endpoint handles all activity field updates in one call — title, readContent, help panel fields, video reference, passage reference — with a `status: "COMPLETE"` field required in every PATCH. This is how the iPhone indicates the activity is authored. The admin panel must always include `status: "COMPLETE"` in every activity update call.

**Primary recommendation:** Extend `programs.domain.ts` with activity actions (add, update, delete, reorder, reset). Add read block and source reference sub-actions. Build a new `activity-detail.ui.ts` store for the per-activity editing panel state. Build `admin-activity-list.vue` as an inline component within the Lessons tab alongside the existing lesson row — clicking a lesson row expands an activity panel below it. No new route is needed.

---

## Standard Stack

### Core (all installed — no new dependencies required)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.30 | Component framework | Installed |
| Pinia | 3.0.4 | State management | Installed, established store pattern |
| vue-draggable-plus | 0.6.1 | Drag-and-drop activity reorder | Installed in Phase 7 |
| reka-ui | 2.9.2 | Dialog (confirm delete) | Installed, used by AdminConfirmDialog |
| axios | 1.11.0 | HTTP client | Installed, CSRF configured |
| lucide-vue-next | 0.577.0 | Icons (Plus, Trash2, GripVertical, Pencil, ChevronDown, ChevronUp) | Installed |

**No new npm dependencies.** All required libraries are already installed. The activity editor uses plain `<textarea>` for all content fields — no Tiptap.

---

## Architecture Patterns

### Recommended File Structure (Phase 8 additions)

```
resources/
├── js/
│   ├── islands/admin-island/
│   │   ├── sections/
│   │   │   └── programs-section.vue        ← EXTEND (add activity panel to Lessons tab)
│   │   └── stores/
│   │       ├── domain/
│   │       │   └── programs.domain.ts       ← EXTEND (add activity CRUD actions)
│   │       └── ui/
│   │           ├── program-detail.ui.ts     ← EXTEND (add expandedLessonId, activity panel state)
│   │           └── activity-detail.ui.ts    ← NEW (per-activity editing state)
│   ├── components/admin/
│   │   └── admin-activity-list/
│   │       ├── admin-activity-list.vue      ← NEW (activity list + type selector + per-activity editor)
│   │       └── admin-activity-list.scss     ← NEW
├── css/
│   └── components/
│       └── admin/
│           └── admin-activity-list.scss     ← IMPORTED by app.scss
```

Activities are shown inline below each lesson row (accordion expand pattern), not on a separate route.

---

## Confirmed API Shapes

All shapes confirmed from `ProgramActions.swift` (lines verified in source).

### Activity Type Enum (CONFIRMED from StudyModels.swift line 652)

```
"SOAP"       — Bible study: Scripture, Observation, Application, Prayer
"OIA"        — Bible study: Observe, Interpret, Apply
"DBS"        — Bible study: Discipleship Bible Study method
"HEAR"       — Bible study: Highlight, Explain, Apply, Respond
"VIDEO"      — Video reference activity
"USER_INPUT" — Study prompt / reflection (always considered configured)
"READ"       — Reading content with optional read blocks
```

For MVP, the REQUIREMENTS.md specifies: READ, VIDEO, USER_INPUT, PRAYER, REFLECTION, SCRIPTURE, SOAP. Note: the iPhone source shows the actual enum as `SOAP`, `OIA`, `DBS`, `HEAR`, `VIDEO`, `USER_INPUT`, `READ`. There is **no PRAYER, REFLECTION, or SCRIPTURE type** in the enum — these appear to be colloquial names in the requirements. The admin panel must use the actual rawValue strings from the enum. Use `USER_INPUT` for "study/reflection" prompts. Confirm with the user if PRAYER and REFLECTION are custom types not yet in the iPhone enum — this is flagged as an open question.

### POST /api/programs/:id/lessons/:lessonId/activities (add activity)

**Source:** ProgramActions.swift line 455
```json
{
  "activityType": "READ",
  "title": "Day 1 Reading"
}
```
Response: `{ "success": true, "activity": { ...StudyActivity } }`

### PATCH /api/activities/:id (update activity)

**Source:** ProgramActions.swift lines 527-561 (`updateActivityContent`)

ALL update calls MUST include `"status": "COMPLETE"`. The API uses this to mark an activity as authored.

```json
{
  "status": "COMPLETE",
  "title": "optional string",
  "readContent": "optional plain text string",
  "isHelpEnabled": false,
  "helpTitle": "optional string",
  "helpDescription": "optional string",
  "helpIcon": "optional string"
}
```

For VIDEO update (ProgramActions.swift line 430):
```json
{
  "videoId": "string",
  "videoUrl": "string",
  "status": "COMPLETE"
}
```

For SOAP/SCRIPTURE passage update (ProgramActions.swift line 384):
```json
{
  "passageReference": "Romans 1:1-5",
  "bookNumber": 45,
  "bookName": "Romans",
  "chapterStart": 1,
  "verseStart": 1,
  "verseEnd": 5,
  "status": "COMPLETE"
}
```

Response: `{ "success": true, "activity": { ...StudyActivity } }`

### DELETE /api/activities/:id

**Source:** ProgramActions.swift line 511
No body. Response: `{ "success": true }`

After delete: remove activity from local `lesson.activities` array by ID.

### POST /api/programs/:id/lessons/:lessonId/reorder-activities

**Source:** ProgramActions.swift line 486
```json
{
  "activityOrder": ["id1", "id2", "id3"]
}
```
Response: `{ "success": true, "activities": [{ ...StudyActivity }] }` — full reordered list returned.

### POST /api/activities/:id/reset

**Source:** ProgramActions.swift line 751
No body required (POST with no body). Response: `{ "success": true, "activity": { ...StudyActivity } }` — activity is reset to `status: "PENDING"`.

### POST /api/activities/:id/read-blocks (create read block)

**Source:** ProgramActions.swift lines 614-651
```json
{
  "isLocked": false,
  "title": "optional string",
  "content": "optional plain text string",
  "orderNumber": 1
}
```
Response: `{ "success": true, "block": { ...ActivityReadBlock }, "activity": { ...StudyActivity } }` — full updated activity returned.

### PATCH /api/activities/:id/read-blocks/:blockId (update read block)

**Source:** ProgramActions.swift lines 656-688
```json
{
  "content": "updated content string"
}
```
To clear content: `{ "content": null }` (send null explicitly).
Response: `{ "success": true }` — no block or activity returned. Update local state manually.

### DELETE /api/activities/:id/read-blocks/:blockId

**Source:** ProgramActions.swift lines 693-715
No body. Response: `{ "success": true, "activity": { ...StudyActivity } }` — full updated activity returned.

### PATCH /api/activities/:id/read-blocks/reorder

**Source:** ProgramActions.swift lines 720-745
```json
{
  "blockIds": ["id1", "id2", "id3"]
}
```
Response: `{ "success": true, "activity": { ...StudyActivity } }` — full updated activity returned.

### POST /api/activities/:id/source-references (add source reference)

**Source:** ProgramActions.swift lines 566-607
```json
{
  "sourceType": "BIBLE_PASSAGE",
  "passageReference": "Romans 1:1-5",
  "bookNumber": 45,
  "bookName": "Romans",
  "chapterStart": 1,
  "verseStart": 1,
  "verseEnd": 5
}
```
Optional field: `"content"` (HTML string from Bible reader — the web admin will not send this).
Response: `{ "success": true, "sourceReference": { ...ActivitySourceReference }, "activity": { ...StudyActivity } }` — updated activity returned.

---

## Data Models (TypeScript interfaces)

These extend the existing `programs.domain.ts` interfaces.

### ActivitySourceReference
```typescript
// Source: StudyModels.swift lines 304-317
interface ActivitySourceReference {
  id: string
  lessonActivityId?: string
  sourceType?: string          // "BIBLE_PASSAGE"
  passageReference?: string    // "Romans 1:1-5"
  bookNumber?: number
  bookName?: string
  chapterStart?: number
  chapterEnd?: number
  verseStart?: number
  verseEnd?: number
  createdAt?: string
  updatedAt?: string
}
```

### ActivityReadBlock
```typescript
// Source: StudyModels.swift lines 320-370
interface ActivityReadBlock {
  id: string
  lessonActivityId?: string
  orderNumber: number
  title?: string
  content?: string             // plain text — NOT HTML, NOT rich text
  isLocked: boolean
  sourceReferenceId?: string
  createdAt?: string
  updatedAt?: string
}
```

### Activity (extends existing Lesson interface in programs.domain.ts)
```typescript
// Source: StudyModels.swift lines 377-646
interface Activity {
  id: string
  lessonId?: string
  activityType: string         // raw value: "SOAP", "OIA", "DBS", "HEAR", "VIDEO", "USER_INPUT", "READ"
  status: string               // "PENDING" | "COMPLETE"
  orderNumber: number
  title?: string
  isHelpEnabled?: boolean
  helpTitle?: string
  helpDescription?: string
  helpIcon?: string
  readContent?: string         // plain text string — NO rich text format
  sourceReferences?: ActivitySourceReference[]
  readBlocks?: ActivityReadBlock[]
  videoId?: string
  videoUrl?: string
  passageReference?: string    // free text e.g. "Romans 1:1-5"
  createdAt?: string
  updatedAt?: string
}
```

The `Lesson` interface in `programs.domain.ts` must be extended to include `activities?: Activity[]`.

---

## Architecture Patterns

### Pattern 1: Activities Inline in Lessons Tab (Accordion)

**What:** Each lesson row in the Lessons tab has a clickable expand button. When expanded, the activities for that lesson are shown below the lesson row in a sub-panel.

**When to use:** Activities are deeply nested. A separate route for `/admin/programs/:id/lessons/:lid` would require additional router setup. The accordion avoids this complexity while keeping context visible (the lesson title is always visible above its activities).

**Structure:**
```
Lessons tab
├── Lesson row (Day 1) [expand button]
│   └── Activity sub-panel (visible when expanded)
│       ├── Activity row: [grip] [type badge] [title] [edit] [delete]
│       ├── Activity row: ...
│       ├── [+ Add Activity] button (opens type selector)
│       └── Activity edit drawer (inline or mini-form below row)
├── Lesson row (Day 2) [expand button]
│   └── Activity sub-panel
...
```

Only one lesson is expanded at a time (`expandedLessonId` in `program-detail.ui.ts`).

**Integration point:** `programs-section.vue` Lessons tab — add expand/collapse toggle and conditionally render `<AdminActivityList>` component below each lesson row.

### Pattern 2: Type-Gated Activity Editor

**What:** After creating an activity (selecting its type), the edit panel shows different fields based on type.

| Activity Type | Fields Shown |
|---------------|-------------|
| READ | title, readContent (textarea), read blocks list (add/edit/delete/reorder) |
| VIDEO | title, videoUrl (text input), videoId (text input) |
| SOAP / OIA / DBS / HEAR | title, passageReference (free text input) |
| USER_INPUT | title only (content is provided by members during study) |

Help panel fields (isHelpEnabled, helpTitle, helpDescription, helpIcon) appear for ALL types below the type-specific content fields. Collapsed by default, expandable.

### Pattern 3: programs.domain.ts Extension

**What:** Add all activity CRUD functions to the existing `useProgramsDomain` store. Activities are loaded as part of the lesson response — no separate fetch needed.

**Key state to update:**
- After `addActivity`: push to `lesson.activities` in the programs array
- After `updateActivity`: replace activity in `lesson.activities` by id
- After `deleteActivity`: splice from `lesson.activities` by id
- After `reorderActivities`: replace entire `lesson.activities` with returned array
- After `resetActivity`: replace activity in `lesson.activities` with returned activity
- Read block mutations: the server returns the updated full activity — replace the entire activity in `lesson.activities`

### Pattern 4: Local Writable Ref for Drag-and-Drop (reuse lessons pattern)

**What:** Same pattern as LSSN-05. `vue-draggable-plus` requires a local writable ref, not a computed. Watch the computed `activities` from the store and sync into `localActivities` ref.

```typescript
// Source: programs-section.vue lines 23-33 (established pattern)
const localActivities = ref<Activity[]>([])
watch(
  () => activitiesForLesson(expandedLessonId.value),
  (newActivities) => { localActivities.value = [...newActivities] },
  { immediate: true, deep: true }
)
```

### Anti-Patterns to Avoid

- **Missing `status: "COMPLETE"` in PATCH**: Every `PATCH /api/activities/:id` call must include `status: "COMPLETE"`. Omitting it leaves the activity in PENDING state and it appears unconfigured to members.
- **Using rich text / HTML for `readContent`**: The field is plain text (or markdown). Sending Tiptap HTML corrupts the member reading experience.
- **Forgetting to include `status` in read block PATCH**: The read block update (`PATCH /api/activities/:id/read-blocks/:blockId`) does NOT require `status` — only the main activity PATCH does.
- **Navigating to a new route for activity editing**: Activities must be edited inline in the Lessons tab accordion. Do not add a new Vue Router route for `/admin/programs/:id/lessons/:lid`.
- **Fetching activities separately**: Activities come embedded in the `GET /api/programs/:id` response (`lesson.activities`). There is no separate "list activities" endpoint.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Activity drag-and-drop reorder | Custom sortable | `vue-draggable-plus` (already installed) | Same pattern as lesson reorder — already working |
| Delete confirmation | Custom confirm modal | `AdminConfirmDialog` (already built) | Zero-effort reuse, consistent UX |
| Activity type selector | Custom dropdown | Native `<select>` with typed options | No need for reka-ui Select for a short static list |
| Read block editing | Rich text editor | Plain `<textarea>` | Content is plain text; Tiptap would mismatch the API |
| Inline title editing | Custom contenteditable | Same inline-edit pattern as lesson title (input + save/cancel buttons) | Already proven in programs-section.vue |

---

## Common Pitfalls

### Pitfall 1: Missing `status: "COMPLETE"` in Activity PATCH

**What goes wrong:** Activity shows as unconfigured (greyed out) in the member app. Members see no content even though the leader saved it.

**Why it happens:** The API differentiates between "this activity has been authored by a leader" (COMPLETE) and "this activity is a template placeholder" (PENDING). The iPhone always sends `status: "COMPLETE"` in every PATCH. The web admin must do the same.

**How to avoid:** Every function in `programs.domain.ts` that calls `PATCH /api/activities/:id` must include `status: "COMPLETE"` in the body unconditionally.

**Warning signs:** Activity content saves without error but members see "content pending" state in the reading experience.

### Pitfall 2: Read Block PATCH Returns No Activity — Must Update Local State Manually

**What goes wrong:** After updating a read block's content, the activity's `readBlocks` array in local store is stale.

**Why it happens:** Unlike other read block operations (create, delete, reorder), the `PATCH /api/activities/:id/read-blocks/:blockId` response only returns `{ success: true }` — no updated block or activity. The iPhone app manually updates the block in its local copy (ProgramActions.swift lines 680-688).

**How to avoid:** After a successful read block PATCH, manually update the block's `content` in the activity's `readBlocks` array in the Pinia store. Do not re-fetch the full program.

**Warning signs:** Read block content appears stale after save (shows old content until page refresh).

### Pitfall 3: Activity Order Race Condition During Drag-and-Drop

**What goes wrong:** Two quick drags produce out-of-order activities if the second drag's API response arrives before the first.

**Why it happens:** The reorder endpoint overwrites the full activity order with the submitted array. Two concurrent calls produce a last-write-wins result that may not match the current visual order.

**How to avoid:** Debounce the `reorderActivities` call by 600ms (same as lesson reorder). Use a single ordered list in the request (not partial updates).

**Warning signs:** Activity order visually jumps back after dragging.

### Pitfall 4: Source Reference Delete Endpoint Unconfirmed

**What goes wrong:** Planning for ACTV-05 includes a delete source reference flow, but the delete endpoint is not confirmed.

**Why it happens:** `ProgramActions.swift` only has `addSourceReference` — there is no `deleteSourceReference` function in the iPhone source. The delete endpoint may not exist or may not be needed for MVP.

**How to avoid:** For MVP, only implement add source reference. Omit delete. If delete is required, it must be confirmed from an API audit before implementation. See Open Questions.

**Warning signs:** Attempting `DELETE /api/activities/:id/source-references/:refId` returns 404.

---

## Code Examples

### Adding activity actions to programs.domain.ts

```typescript
// Source: ProgramActions.swift lines 453-475 (addActivity)
// Add to useProgramsDomain in resources/js/islands/admin-island/stores/domain/programs.domain.ts

async function addActivity(
  programId: string,
  lessonId: string,
  activityType: string,
  title: string
): Promise<void> {
  error.value = null
  try {
    const res = await axios.post(
      `/admin/api/programs/${programId}/lessons/${lessonId}/activities`,
      { activityType, title }
    )
    const newActivity: Activity = res.data.activity
    const program = programs.value.find((p) => p.id === programId)
    const lesson = program?.lessons?.find((l) => l.id === lessonId)
    if (lesson) {
      if (!lesson.activities) lesson.activities = []
      lesson.activities.push(newActivity)
    }
  } catch (err: any) {
    error.value = err?.response?.data?.message ?? 'Failed to add activity'
    throw err
  }
}

// Source: ProgramActions.swift lines 527-561 (updateActivityContent)
async function updateActivity(
  activityId: string,
  programId: string,
  lessonId: string,
  payload: UpdateActivityPayload
): Promise<void> {
  error.value = null
  try {
    // CRITICAL: always send status: "COMPLETE"
    const res = await axios.patch(`/admin/api/activities/${activityId}`, {
      ...payload,
      status: 'COMPLETE',
    })
    const updated: Activity = res.data.activity
    const program = programs.value.find((p) => p.id === programId)
    const lesson = program?.lessons?.find((l) => l.id === lessonId)
    if (lesson?.activities) {
      const idx = lesson.activities.findIndex((a) => a.id === activityId)
      if (idx !== -1) lesson.activities.splice(idx, 1, updated)
    }
  } catch (err: any) {
    error.value = err?.response?.data?.message ?? 'Failed to update activity'
    throw err
  }
}

// Source: ProgramActions.swift lines 509-523 (deleteActivity)
async function deleteActivity(
  activityId: string,
  programId: string,
  lessonId: string
): Promise<void> {
  error.value = null
  try {
    await axios.delete(`/admin/api/activities/${activityId}`)
    const program = programs.value.find((p) => p.id === programId)
    const lesson = program?.lessons?.find((l) => l.id === lessonId)
    if (lesson?.activities) {
      lesson.activities = lesson.activities.filter((a) => a.id !== activityId)
    }
  } catch (err: any) {
    error.value = err?.response?.data?.message ?? 'Failed to delete activity'
    throw err
  }
}

// Source: ProgramActions.swift lines 478-506 (reorderActivities)
async function reorderActivities(
  programId: string,
  lessonId: string,
  activityIds: string[]
): Promise<void> {
  error.value = null
  try {
    const res = await axios.post(
      `/admin/api/programs/${programId}/lessons/${lessonId}/reorder-activities`,
      { activityOrder: activityIds }
    )
    const reordered: Activity[] = res.data.activities
    const program = programs.value.find((p) => p.id === programId)
    const lesson = program?.lessons?.find((l) => l.id === lessonId)
    if (lesson) lesson.activities = reordered
  } catch (err: any) {
    error.value = err?.response?.data?.message ?? 'Failed to reorder activities'
    throw err
  }
}

// Source: ProgramActions.swift lines 749-764 (resetActivity)
async function resetActivity(
  activityId: string,
  programId: string,
  lessonId: string
): Promise<void> {
  error.value = null
  try {
    const res = await axios.post(`/admin/api/activities/${activityId}/reset`)
    const reset: Activity = res.data.activity
    const program = programs.value.find((p) => p.id === programId)
    const lesson = program?.lessons?.find((l) => l.id === lessonId)
    if (lesson?.activities) {
      const idx = lesson.activities.findIndex((a) => a.id === activityId)
      if (idx !== -1) lesson.activities.splice(idx, 1, reset)
    }
  } catch (err: any) {
    error.value = err?.response?.data?.message ?? 'Failed to reset activity'
    throw err
  }
}
```

### Read block PATCH (manual local state update required)

```typescript
// Source: ProgramActions.swift lines 656-688 (updateReadBlock)
async function updateReadBlock(
  activityId: string,
  blockId: string,
  content: string | null,
  programId: string,
  lessonId: string
): Promise<void> {
  error.value = null
  try {
    // NOTE: no status field needed for read block PATCH
    await axios.patch(
      `/admin/api/activities/${activityId}/read-blocks/${blockId}`,
      { content: content }
    )
    // Server returns only { success: true } — update local state manually
    const program = programs.value.find((p) => p.id === programId)
    const lesson = program?.lessons?.find((l) => l.id === lessonId)
    const activity = lesson?.activities?.find((a) => a.id === activityId)
    if (activity?.readBlocks) {
      const block = activity.readBlocks.find((b) => b.id === blockId)
      if (block) block.content = content ?? undefined
    }
  } catch (err: any) {
    error.value = err?.response?.data?.message ?? 'Failed to update read block'
    throw err
  }
}
```

### Adding source reference

```typescript
// Source: ProgramActions.swift lines 566-607 (addSourceReference)
async function addSourceReference(
  activityId: string,
  programId: string,
  lessonId: string,
  passageReference: string,
  bookNumber: number,
  bookName: string,
  chapterStart: number,
  verseStart: number,
  verseEnd: number,
  chapterEnd?: number
): Promise<void> {
  error.value = null
  try {
    const body: Record<string, any> = {
      sourceType: 'BIBLE_PASSAGE',
      passageReference,
      bookNumber,
      bookName,
      chapterStart,
      verseStart,
      verseEnd,
    }
    if (chapterEnd !== undefined) body.chapterEnd = chapterEnd

    const res = await axios.post(
      `/admin/api/activities/${activityId}/source-references`,
      body
    )
    // Response includes updated activity with all sourceReferences
    if (res.data.activity) {
      const program = programs.value.find((p) => p.id === programId)
      const lesson = program?.lessons?.find((l) => l.id === lessonId)
      if (lesson?.activities) {
        const idx = lesson.activities.findIndex((a) => a.id === activityId)
        if (idx !== -1) lesson.activities.splice(idx, 1, res.data.activity)
      }
    }
  } catch (err: any) {
    error.value = err?.response?.data?.message ?? 'Failed to add source reference'
    throw err
  }
}
```

### Activity type display labels

```typescript
// Source: StudyModels.swift lines 661-667 (displayName)
const ACTIVITY_TYPE_LABELS: Record<string, string> = {
  'SOAP': 'SOAP',
  'OIA': 'OIA',
  'DBS': 'DBS',
  'HEAR': 'HEAR',
  'VIDEO': 'Video',
  'USER_INPUT': 'Study',
  'READ': 'Read',
}
```

---

## State of the Art

| Old Assumption | Confirmed Reality | Impact |
|----------------|------------------|--------|
| Activity content uses rich text (Tiptap) | readContent is plain text string; readBlocks.content is plain text | No Tiptap needed — `<textarea>` is correct for MVP |
| PATCH /api/activities/:id may not need status | `status: "COMPLETE"` is REQUIRED in every PATCH | Must be included; omitting silently leaves activity as PENDING |
| Read block reorder uses different key name | `{ "blockIds": [...] }` confirmed (ProgramActions.swift line 721) | Key is `blockIds`, not `blockOrder` or `orderedIds` |
| Activity reorder uses `activityIds` | `{ "activityOrder": [...] }` confirmed (ProgramActions.swift line 486) | Key is `activityOrder`, parallel to `lessonOrder` |
| Source reference delete exists | NOT confirmed in iPhone source — only addSourceReference is implemented | MVP should not include source reference delete |

---

## Open Questions

1. **Activity types PRAYER, REFLECTION, SCRIPTURE**
   - What we know: The iPhone `ActivityType` enum has: SOAP, OIA, DBS, HEAR, VIDEO, USER_INPUT, READ
   - What's unclear: REQUIREMENTS.md lists "PRAYER, REFLECTION, SCRIPTURE" as selectable types — these do not appear in the iPhone enum
   - Recommendation: These may be USER_INPUT activities with different `title` defaults. Confirm with user whether PRAYER/REFLECTION/SCRIPTURE are separate enum values or just named USER_INPUT activities. For MVP, use USER_INPUT for all prompt-style activities and let the title differentiate them.

2. **Source reference delete endpoint**
   - What we know: `POST /api/activities/:id/source-references` adds a reference. The iPhone has no delete function.
   - What's unclear: Can source references be deleted? Is there a `DELETE /api/activities/:id/source-references/:refId`?
   - Recommendation: For MVP, only implement "add source reference". Do not build delete. The reset (`POST /api/activities/:id/reset`) clears all content including source references.

3. **Activity list loading — activities already in lesson response**
   - What we know: `GET /api/programs/:id?lessonPage=1&lessonLimit=30` returns `{ program: { lessons: [{ ..., activities: [...] }] } }` — activities are embedded
   - What's unclear: Whether activities include full `readBlocks` and `sourceReferences` arrays in the list response, or only top-level fields
   - Recommendation: Load activities via the existing `getProgram()` call. If `readBlocks` are absent in the list response, fetch the individual program detail again when a user expands a lesson. The current `getProgram` already loads all lesson data — verify that readBlocks populate in the returned activities before building the read block editor.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel feature tests) |
| Config file | `phpunit.xml` |
| Quick run command | `php artisan test --filter ActivitiesAdminTest` |
| Full suite command | `php artisan test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ACTV-01 | GET /admin/api/programs/:id returns activities in lesson response | Feature | `php artisan test --filter ActivitiesAdminTest::test_get_program_returns_activities` | Wave 0 |
| ACTV-02 | POST /admin/api/programs/:id/lessons/:lid/activities proxies to API | Feature | `php artisan test --filter ActivitiesAdminTest::test_add_activity` | Wave 0 |
| ACTV-03 | PATCH /admin/api/activities/:id proxies update with status field | Feature | `php artisan test --filter ActivitiesAdminTest::test_update_activity` | Wave 0 |
| ACTV-04 | PATCH readContent saves plain text to API | Feature | `php artisan test --filter ActivitiesAdminTest::test_update_read_content` | Wave 0 |
| ACTV-05 | POST /admin/api/activities/:id/source-references proxies correctly | Feature | `php artisan test --filter ActivitiesAdminTest::test_add_source_reference` | Wave 0 |
| ACTV-06 | POST/PATCH/DELETE/reorder read-blocks endpoints proxy correctly | Feature | `php artisan test --filter ActivitiesAdminTest::test_read_block_crud` | Wave 0 |
| ACTV-07 | DELETE /admin/api/activities/:id proxies to API | Feature | `php artisan test --filter ActivitiesAdminTest::test_delete_activity` | Wave 0 |
| ACTV-08 | POST reorder-activities proxies with activityOrder key | Feature | `php artisan test --filter ActivitiesAdminTest::test_reorder_activities` | Wave 0 |
| ACTV-09 | POST /admin/api/activities/:id/reset proxies correctly | Feature | `php artisan test --filter ActivitiesAdminTest::test_reset_activity` | Wave 0 |

### Sampling Rate

- **Per task commit:** `php artisan test --filter ActivitiesAdminTest`
- **Per wave merge:** `php artisan test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/Feature/ActivitiesAdminTest.php` — covers ACTV-01 through ACTV-09 (proxy tests using `Http::fake()`)

Follow the pattern from `tests/Feature/ProgramsAdminTest.php`: use `Http::fake()` per test, call proxy routes via `$this->getJson`/`$this->postJson`/`$this->patchJson`/`$this->deleteJson`, assert upstream body forwarded and response returned.

---

## Sources

### Primary (HIGH confidence)

- `/Users/lukekeith/www/makeready/iphone/MakeReady/State/Actions/ProgramActions.swift` — all activity CRUD endpoints confirmed (addActivity, updateActivity, deleteActivity, reorderActivities, resetActivity, createReadBlock, updateReadBlock, deleteReadBlock, reorderReadBlocks, addSourceReference)
- `/Users/lukekeith/www/makeready/iphone/MakeReady/Pages/Manage/Program/Models/StudyModels.swift` — `StudyActivity`, `ActivityType`, `ActivityReadBlock`, `ActivitySourceReference` model definitions with all fields
- `/Users/lukekeith/www/makeready/client/resources/js/islands/admin-island/stores/domain/programs.domain.ts` — existing store pattern to extend
- `/Users/lukekeith/www/makeready/client/resources/js/islands/admin-island/stores/ui/program-detail.ui.ts` — existing UI store to extend
- `/Users/lukekeith/www/makeready/client/resources/js/islands/admin-island/sections/programs-section.vue` — integration point (Lessons tab accordion expansion)
- `/Users/lukekeith/www/makeready/client/tests/Feature/ProgramsAdminTest.php` — test pattern for proxy tests
- `.planning/phases/07-programs-lessons/07-RESEARCH.md` — established patterns for lessons reorder and vue-draggable-plus

### Secondary (MEDIUM confidence)

- `.planning/research/SUMMARY.md` — overall architecture decisions and pitfall documentation
- `.planning/research/FEATURES.md` — API surface summary for activity endpoints
- `.planning/STATE.md` — blocker documentation for Phase 8 activity content format

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Activity CRUD API shapes | HIGH | All confirmed from ProgramActions.swift direct source read |
| Data model field names | HIGH | Confirmed from StudyModels.swift direct source read |
| `status: "COMPLETE"` requirement | HIGH | Explicitly confirmed in ProgramActions.swift updateActivityContent |
| Read block API shapes | HIGH | All four operations confirmed from ProgramActions.swift |
| Source reference add shape | HIGH | Confirmed from ProgramActions.swift addSourceReference |
| Source reference delete | LOW | No delete function found in iPhone source |
| Activity type enum values | HIGH | Confirmed from StudyModels.swift ActivityType enum |
| PRAYER/REFLECTION/SCRIPTURE types | LOW | Not found in iPhone enum — clarification needed |
| readContent format (plain text) | HIGH | Confirmed from StudyModels.swift — no rich text markers |

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (API is stable — no API changes in scope per REQUIREMENTS.md)
