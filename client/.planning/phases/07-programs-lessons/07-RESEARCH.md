# Phase 7: Programs + Lessons - Research

**Researched:** 2026-03-20
**Domain:** Vue 3 + Pinia CRUD — programs entity with nested lessons list and reorder
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PROG-01 | Leader can view a list of all programs with name, cover image, lesson count, and publish status | `GET /api/programs` confirmed; response `{ success, programs: [...] }` — each program has `id`, `name`, `coverImageUrl`, `isPublished`, `_count.enrollments`, lessons attached when fetched by ID |
| PROG-02 | Leader can create a new program (name, description, template selection) | `POST /api/programs` confirmed; required: `name`, `templateId`, `days`; optional: `description`, `isPublished`, `coverImageUrl`; template list from `GET /api/templates` |
| PROG-03 | Leader can edit program metadata (name, description) | `PATCH /api/programs/:id` confirmed; all fields optional partial update; response `{ success, program }` |
| PROG-04 | Leader can upload/change a program cover image | `POST /api/programs/:id/cover-image` confirmed; multipart upload identical to group cover image pattern; response `{ success, coverImageUrl }` |
| PROG-05 | Leader can publish or unpublish a program | `PATCH /api/programs/:id` with `{ isPublished: true/false }`; same endpoint as PROG-03; toggle implemented as a button in the programs list row or program detail header |
| PROG-06 | Leader can delete a program (with confirmation) | `DELETE /api/programs/:id` confirmed; response `{ success }`; uses existing `AdminConfirmDialog` |
| PROG-07 | Program detail view has tabs for Lessons and Enrollments | Two-tab layout using existing `TabsRoot/TabsList/TabsTrigger/TabsContent` from reka-ui; Lessons tab is implemented this phase; Enrollments tab is a stub (Phase 9) |
| LSSN-01 | Leader can view list of lessons within a program, showing day number and title | Lessons included in `GET /api/programs/:id` response (with pagination params `lessonPage=1&lessonLimit=30`); each lesson has `id`, `dayNumber`, `title` |
| LSSN-02 | Leader can add a new lesson (day) to a program | `POST /api/programs/:programId/lessons` with empty body `{}`; response `{ success, lesson }` with auto-assigned `dayNumber` |
| LSSN-03 | Leader can edit a lesson title | `PATCH /api/programs/:programId/lessons/:lessonId` with `{ title: string }`; response `{ success }` — no lesson returned, only success flag |
| LSSN-04 | Leader can delete a lesson (with confirmation) | `DELETE /api/programs/:programId/lessons/:lessonId`; response `{ success }`; iPhone refreshes full program after delete — web should too |
| LSSN-05 | Leader can reorder lessons via drag-and-drop | `POST /api/programs/:programId/reorder-lessons` with `{ lessonOrder: [id, id, ...] }` (CONFIRMED key name); response `{ success, program }` with reordered program; vue-draggable-plus for drag-and-drop |
</phase_requirements>

---

## Summary

Phase 7 builds the complete Programs CRUD feature plus the nested Lessons list inside the program detail view. The pattern is a direct parallel to Phase 6 (Groups CRUD) — same domain/UI store separation, same reusable `AdminTable`, `AdminForm`, `AdminConfirmDialog`, and `AdminImageUpload` components, same proxy controller forwarding to the external API. The only new concerns are: (1) the create-program form needs a template selector driven by `GET /api/templates`; (2) the `isPublished` toggle is a distinct UI action on each program; (3) the lessons list is a nested entity inside the program detail view (not a separate route), requiring a lessons sub-store under the programs domain; (4) drag-and-drop lesson reorder via `vue-draggable-plus` is required for LSSN-05.

The critical resolved question from STATE.md is the lessons reorder request body key: it is `lessonOrder` (confirmed directly from `ProgramActions.swift` line 362: `let body: [String: Any] = ["lessonOrder": lessonIds]`). This was previously flagged as unconfirmed.

The critical unresolved question for this phase is lesson count in the programs list (`PROG-01`). The `GET /api/programs` response structure is confirmed via `ProgramActions.swift`, which accesses `program._count?.enrollments` — the `_count` field is present for enrollments. Whether `_count.lessons` (or a similar field) is also returned in the list response is unconfirmed. The safe approach: show lesson count as `—` if the field is absent and only show it when fetching the single program detail.

**Primary recommendation:** Build `programs.domain.ts` first, then `programs-list.ui.ts`, then `programs-section.vue` list view. Add program detail with the two-tab shell next. Then add lessons list (load, add, edit, delete) inside the Lessons tab. Add drag-and-drop reorder last as it requires `vue-draggable-plus`.

---

## Standard Stack

### Core (all already installed — no new dependencies for list/CRUD)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.30 | Component framework | Installed |
| Pinia | 3.0.4 | State management | Installed, same pattern as groups.domain.ts |
| Vue Router | 4.6.4 | Client-side routing | Installed, `/admin/programs` and `/admin/programs/:id` routes pre-registered in router.ts |
| axios | 1.11.0 | HTTP client | Installed, CSRF configured in AdminIsland onMounted |
| reka-ui | 2.9.2 | Headless UI (Tabs, Dialog) | Installed, used in groups-section.vue |
| lucide-vue-next | 0.577.0 | Icons (ArrowLeft, GripVertical) | Installed, used in groups-section.vue |

### New Dependency: vue-draggable-plus (for LSSN-05)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| vue-draggable-plus | 0.6.1 | Drag-and-drop list reorder | Actively maintained SortableJS wrapper for Vue 3; confirmed last updated January 2026 |

**Installation (only needed for drag-and-drop):**
```bash
npm install vue-draggable-plus
```

If LSSN-05 is deferred to a later wave, skip this install. Up/down arrow buttons are a viable MVP fallback that require no new library.

### Reused Components (no changes needed)

All four admin display components from Phase 6 are used as-is:
- `AdminTable` — programs list
- `AdminForm` — create/edit program modal (modal mode), edit lesson title (inline mode)
- `AdminConfirmDialog` — delete program, delete lesson
- `AdminImageUpload` — program cover image upload

---

## Architecture Patterns

### Recommended File Structure (Phase 7 additions)

```
resources/
├── js/
│   ├── islands/admin-island/
│   │   ├── sections/
│   │   │   └── programs-section.vue        ← REWRITE (stub → real implementation)
│   │   └── stores/
│   │       ├── domain/
│   │       │   ├── groups.domain.ts         (existing — do not modify)
│   │       │   └── programs.domain.ts       ← NEW
│   │       └── ui/
│   │           ├── groups-list.ui.ts        (existing — do not modify)
│   │           ├── group-detail.ui.ts       (existing — do not modify)
│   │           ├── programs-list.ui.ts      ← NEW
│   │           └── program-detail.ui.ts     ← NEW
├── css/
│   └── components/
│       └── admin/
│           └── admin-lesson-list.scss       ← NEW (lessons list within program detail)
```

app.scss already imports all existing admin SCSS files. Add admin-lesson-list.scss under the `// Admin components` section.

No new Blade routes needed — `/admin/programs` and `/admin/programs/:id` are already registered in `router.ts` and served by the existing Laravel catch-all.

---

### Pattern 1: Programs Domain Store

**What:** `programs.domain.ts` owns all raw API calls for programs and nested lessons. Mirrors the shape of `groups.domain.ts` exactly.

**Key confirmed API shapes from ProgramActions.swift:**

**POST /api/programs (create):**
```json
{
  "name": "string (required)",
  "templateId": "string (required)",
  "days": 0,
  "isPublished": false,
  "description": "optional string",
  "coverImageUrl": "optional string"
}
```
Response: `{ success: true, program: { id, name, isPublished, ... } }`

**PATCH /api/programs/:id (update):**
All fields optional. Same response shape as create.

**DELETE /api/programs/:id:**
No body. Response: `{ success: true }`

**POST /api/programs/:id/cover-image:**
Multipart with `image` key (identical to group cover image — same `AdminApiProxyController.handlePost()` detection). Response: `{ success: true, coverImageUrl: "..." }`

**GET /api/programs (list):**
Response: `{ success: true, programs: [...] }` — each program has `_count: { enrollments: N }` confirmed.

**GET /api/programs/:id (single with lessons):**
Query params: `?lessonPage=1&lessonLimit=30`
Response: `{ success: true, program: { ..., lessons: [...] }, pagination: {...} }`

**POST /api/programs/:id/lessons (add lesson):**
Body: `{}` (empty object — confirmed from Swift `body: [:]`)
Response: `{ success: true, lesson: { id, dayNumber, title, ... } }`

**PATCH /api/programs/:id/lessons/:lessonId (edit title):**
Body: `{ "title": "string" }`
Response: `{ success: true }` — NOTE: no lesson returned, only success flag

**DELETE /api/programs/:id/lessons/:lessonId:**
No body. Response: `{ success: true }` — iPhone re-fetches full program after delete.

**POST /api/programs/:id/reorder-lessons (reorder):**
Body: `{ "lessonOrder": ["id1", "id2", ...] }` — KEY NAME IS `lessonOrder` (CONFIRMED)
Response: `{ success: true, program: { ..., lessons: [...] } }`

**GET /api/templates (template list for create form):**
Response: `{ success: true, templates: [...] }` — each template has `id`, `name` (minimum fields confirmed from Swift `ListTemplatesResponse`)

```typescript
// resources/js/islands/admin-island/stores/domain/programs.domain.ts
import { ref } from 'vue'
import { defineStore } from 'pinia'
import axios from 'axios'

export interface Program {
  id: string
  name: string
  description?: string
  coverImageUrl?: string
  isPublished: boolean
  days?: number
  lessons?: Lesson[]
  _count?: { enrollments: number }
}

export interface Lesson {
  id: string
  dayNumber: number
  title: string
  programId: string
}

export interface Template {
  id: string
  name: string
}

export interface CreateProgramPayload {
  name: string
  templateId: string
  days: number
  description?: string
  isPublished?: boolean
}

export interface UpdateProgramPayload {
  name?: string
  description?: string
  isPublished?: boolean
  days?: number
  coverImageUrl?: string
}

export const useProgramsDomain = defineStore('programs-domain', () => {
  const programs = ref<Program[]>([])
  const templates = ref<Template[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadPrograms(): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      const res = await axios.get('/admin/api/programs')
      programs.value = res.data.programs ?? []
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load programs'
    } finally {
      isLoading.value = false
    }
  }

  async function loadTemplates(): Promise<void> {
    if (templates.value.length > 0) return  // cache: load once per session
    try {
      const res = await axios.get('/admin/api/templates')
      templates.value = res.data.templates ?? []
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load templates'
    }
  }

  async function getProgram(id: string): Promise<void> {
    error.value = null
    try {
      const res = await axios.get(`/admin/api/programs/${id}?lessonPage=1&lessonLimit=30`)
      const fetched: Program = res.data.program
      const idx = programs.value.findIndex((p) => p.id === id)
      if (idx !== -1) {
        programs.value.splice(idx, 1, fetched)
      } else {
        programs.value.push(fetched)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to load program'
    }
  }

  async function createProgram(payload: CreateProgramPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.post('/admin/api/programs', payload)
      programs.value.push(res.data.program)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to create program'
      throw err
    }
  }

  async function updateProgram(id: string, payload: UpdateProgramPayload): Promise<void> {
    error.value = null
    try {
      const res = await axios.patch(`/admin/api/programs/${id}`, payload)
      const updated: Program = res.data.program
      const idx = programs.value.findIndex((p) => p.id === id)
      if (idx !== -1) {
        programs.value.splice(idx, 1, updated)
      } else {
        programs.value.push(updated)
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to update program'
      throw err
    }
  }

  async function deleteProgram(id: string): Promise<void> {
    error.value = null
    try {
      await axios.delete(`/admin/api/programs/${id}`)
      programs.value = programs.value.filter((p) => p.id !== id)
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to delete program'
      throw err
    }
  }

  async function uploadCoverImage(id: string, file: File): Promise<void> {
    error.value = null
    try {
      const formData = new FormData()
      formData.append('image', file)
      const res = await axios.post(`/admin/api/programs/${id}/cover-image`, formData)
      const idx = programs.value.findIndex((p) => p.id === id)
      if (idx !== -1) {
        programs.value.splice(idx, 1, {
          ...programs.value[idx],
          coverImageUrl: res.data.coverImageUrl,
        })
      }
    } catch (err: any) {
      error.value = err?.response?.data?.message ?? 'Failed to upload cover image'
      throw err
    }
  }

  async function addLesson(programId: string): Promise<void> {
    const res = await axios.post(`/admin/api/programs/${programId}/lessons`, {})
    const lesson: Lesson = res.data.lesson
    const program = programs.value.find((p) => p.id === programId)
    if (program) {
      program.lessons = [...(program.lessons ?? []), lesson]
    }
  }

  async function updateLessonTitle(
    programId: string,
    lessonId: string,
    title: string
  ): Promise<void> {
    await axios.patch(`/admin/api/programs/${programId}/lessons/${lessonId}`, { title })
    // Response is { success } only — update local state manually
    const program = programs.value.find((p) => p.id === programId)
    if (program?.lessons) {
      const lesson = program.lessons.find((l) => l.id === lessonId)
      if (lesson) lesson.title = title
    }
  }

  async function deleteLesson(programId: string, lessonId: string): Promise<void> {
    await axios.delete(`/admin/api/programs/${programId}/lessons/${lessonId}`)
    // Re-fetch full program to get updated dayNumbers after deletion
    await getProgram(programId)
  }

  async function reorderLessons(programId: string, lessonIds: string[]): Promise<void> {
    const res = await axios.post(`/admin/api/programs/${programId}/reorder-lessons`, {
      lessonOrder: lessonIds,  // CONFIRMED key name from ProgramActions.swift
    })
    // Response returns updated program with reordered lessons
    const updated: Program = res.data.program
    const idx = programs.value.findIndex((p) => p.id === programId)
    if (idx !== -1) {
      programs.value.splice(idx, 1, updated)
    }
  }

  return {
    programs,
    templates,
    isLoading,
    error,
    loadPrograms,
    loadTemplates,
    getProgram,
    createProgram,
    updateProgram,
    deleteProgram,
    uploadCoverImage,
    addLesson,
    updateLessonTitle,
    deleteLesson,
    reorderLessons,
  }
})
```

---

### Pattern 2: Programs List UI Store

**What:** `programs-list.ui.ts` consumes `programs.domain.ts` and computes exactly the props that `programs-section.vue` and `AdminTable` need. Owns form open/close, publish toggle state, and template selector values.

```typescript
// resources/js/islands/admin-island/stores/ui/programs-list.ui.ts
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRouter } from 'vue-router'
import { useProgramsDomain } from '../domain/programs.domain'

export const useProgramsListUI = defineStore('programs-list-ui', () => {
  const domain = useProgramsDomain()
  const router = useRouter()

  const isCreateFormOpen = ref(false)
  const editingProgramId = ref<string | null>(null)
  const confirmDeleteId = ref<string | null>(null)
  const formError = ref<string | null>(null)
  const isEditing = computed(() => editingProgramId.value !== null)

  const tableColumns = ['Name', 'Lessons', 'Status']

  const tableRows = computed(() =>
    domain.programs.map((p) => ({
      id: p.id,
      cells: [
        p.name,
        p.lessons != null ? `${p.lessons.length} lessons` : '—',
        p.isPublished ? 'Published' : 'Draft',
      ],
      coverImageUrl: p.coverImageUrl,
      badge: p.isPublished ? 'Published' : 'Draft',
    }))
  )

  const editingProgram = computed(() =>
    editingProgramId.value
      ? domain.programs.find((p) => p.id === editingProgramId.value) ?? null
      : null
  )

  const confirmDeleteProgram = computed(() =>
    confirmDeleteId.value
      ? domain.programs.find((p) => p.id === confirmDeleteId.value) ?? null
      : null
  )

  const templateOptions = computed(() =>
    domain.templates.map((t) => ({ value: t.id, label: t.name }))
  )

  function openCreateForm() {
    editingProgramId.value = null
    formError.value = null
    isCreateFormOpen.value = true
  }

  function openEditForm(id: string) {
    editingProgramId.value = id
    formError.value = null
    isCreateFormOpen.value = true
  }

  function closeForm() {
    isCreateFormOpen.value = false
    editingProgramId.value = null
    formError.value = null
  }

  function requestDelete(id: string) {
    confirmDeleteId.value = id
  }

  function cancelDelete() {
    confirmDeleteId.value = null
  }

  function navigateToDetail(id: string) {
    router.push(`/admin/programs/${id}`)
  }

  return {
    tableColumns,
    tableRows,
    isCreateFormOpen,
    isEditing,
    editingProgramId,
    editingProgram,
    confirmDeleteProgram,
    formError,
    templateOptions,
    openCreateForm,
    openEditForm,
    closeForm,
    requestDelete,
    cancelDelete,
    navigateToDetail,
  }
})
```

---

### Pattern 3: Program Detail UI Store

**What:** `program-detail.ui.ts` consumes `programs.domain.ts` and computes display props for the selected program's detail view and lessons list.

```typescript
// resources/js/islands/admin-island/stores/ui/program-detail.ui.ts
import { ref, computed } from 'vue'
import { defineStore } from 'pinia'
import { useRoute } from 'vue-router'
import { useProgramsDomain } from '../domain/programs.domain'

export const useProgramDetailUI = defineStore('program-detail-ui', () => {
  const domain = useProgramsDomain()
  const route = useRoute()

  const activeTab = ref('lessons')
  const editingLessonId = ref<string | null>(null)
  const confirmDeleteLessonId = ref<string | null>(null)
  const isUploadingCover = ref(false)
  const isSavingMetadata = ref(false)
  const metadataError = ref<string | null>(null)

  const currentProgram = computed(() =>
    domain.programs.find((p) => p.id === route.params.id) ?? null
  )

  const pageTitle = computed(() => currentProgram.value?.name ?? 'Program')

  const lessons = computed(() => currentProgram.value?.lessons ?? [])

  const editingLesson = computed(() =>
    editingLessonId.value
      ? lessons.value.find((l) => l.id === editingLessonId.value) ?? null
      : null
  )

  const confirmDeleteLesson = computed(() =>
    confirmDeleteLessonId.value
      ? lessons.value.find((l) => l.id === confirmDeleteLessonId.value) ?? null
      : null
  )

  const metadataFormValues = computed(() => {
    const p = currentProgram.value
    if (!p) return {}
    return {
      name: p.name,
      description: p.description ?? '',
    }
  })

  const metadataFields = [
    { key: 'name', label: 'Program Name', type: 'text' as const, required: true },
    { key: 'description', label: 'Description', type: 'textarea' as const },
  ]

  function openEditLesson(id: string) {
    editingLessonId.value = id
  }

  function closeEditLesson() {
    editingLessonId.value = null
  }

  function requestDeleteLesson(id: string) {
    confirmDeleteLessonId.value = id
  }

  function cancelDeleteLesson() {
    confirmDeleteLessonId.value = null
  }

  return {
    activeTab,
    editingLessonId,
    confirmDeleteLessonId,
    isUploadingCover,
    isSavingMetadata,
    metadataError,
    currentProgram,
    pageTitle,
    lessons,
    editingLesson,
    confirmDeleteLesson,
    metadataFormValues,
    metadataFields,
    openEditLesson,
    closeEditLesson,
    requestDeleteLesson,
    cancelDeleteLesson,
  }
})
```

---

### Pattern 4: Programs Section Component (Orchestrator)

**What:** `programs-section.vue` follows the identical structure as `groups-section.vue`. Detects list vs detail via `route.params.id`. Calls domain store methods; pure display components emit events up to this component.

Key structural notes:
- The `v-if="route.params.id"` / `v-else` branch pattern is identical to groups-section.vue
- `onMounted` + `watch(route.params.id)` pattern reused verbatim from groups-section.vue
- Create form uses `templateId` as a `select` field (loaded via `domain.loadTemplates()` in `onMounted`)
- `isPublished` toggle: not in `AdminForm` fields — standalone button in the list table's row action area or a dedicated toggle button in program detail header
- Lesson list in the Lessons tab: uses a new `AdminLessonList` sub-component or inline rendering within the tab content

---

### Pattern 5: Template Selector in Create Form

**What:** The create-program form requires a `templateId` select field. Templates are loaded from `GET /api/templates` and cached in `programs.domain.ts`. The `AdminForm` component's `select` field type handles this.

```typescript
// In programs-section.vue — create form field definitions
const createFields = computed(() => [
  { key: 'name', label: 'Program Name', type: 'text' as const, required: true },
  { key: 'description', label: 'Description', type: 'textarea' as const },
  {
    key: 'templateId',
    label: 'Template',
    type: 'select' as const,
    required: true,
    options: listUI.templateOptions,
  },
  { key: 'days', label: 'Number of Days', type: 'number' as const, required: true },
])

// In onMounted — load templates before opening create form
onMounted(async () => {
  if (!route.params.id) {
    await Promise.all([domain.loadPrograms(), domain.loadTemplates()])
  } else {
    await domain.getProgram(route.params.id as string)
  }
})
```

**Note:** `days` is required by the API. Default value of `30` is reasonable and can be pre-filled in the form.

---

### Pattern 6: Publish/Unpublish Toggle

**What:** `isPublished` is a boolean toggled via `PATCH /api/programs/:id` with `{ isPublished: boolean }`. This is the same endpoint as metadata edit — not a dedicated endpoint.

**Implementation approach:** A button/badge in the programs list row (via AdminTable's row actions area or a custom slot) or a toggle button in the program detail header. Since `AdminTable` does not have a custom slot for actions beyond edit/delete, the simplest approach is to add a publish toggle as a third action button in the table row action column. This requires either adding a `togglePublish` emit to `AdminTable` or wrapping the programs list table in a custom section that adds the toggle.

**Recommended:** Add `@toggle` emit to AdminTable props for Phase 7 (minimal extension). Alternatively, handle publish toggle only from the program detail header — this is simpler and avoids modifying `AdminTable`.

The detail header approach is cleaner:
```vue
<!-- In programs-section.vue detail branch header -->
<button
  class="AdminSection__action-btn"
  :class="{ 'AdminSection__action-btn--active': detailUI.currentProgram?.isPublished }"
  @click="handleTogglePublish"
>
  {{ detailUI.currentProgram?.isPublished ? 'Unpublish' : 'Publish' }}
</button>
```

---

### Pattern 7: Drag-and-Drop Lesson Reorder (vue-draggable-plus)

**What:** vue-draggable-plus wraps SortableJS with a Vue 3 directive. The `v-draggable` directive is applied to the lessons list container. After drag, emit the new ordered IDs to the domain store's `reorderLessons()`.

**Directive mode:**
```vue
<script setup>
import { VueDraggable } from 'vue-draggable-plus'
// lessons is a ref<Lesson[]> local copy (never the computed directly)
const localLessons = ref([...detailUI.lessons])

async function handleReorder() {
  const ids = localLessons.value.map(l => l.id)
  await domain.reorderLessons(route.params.id as string, ids)
}
</script>

<template>
  <VueDraggable
    v-model="localLessons"
    :animation="200"
    handle=".AdminLessonList__drag-handle"
    @end="handleReorder"
  >
    <div
      v-for="lesson in localLessons"
      :key="lesson.id"
      class="AdminLessonList__item"
    >
      <span class="AdminLessonList__drag-handle">
        <GripVertical :size="16" />
      </span>
      <span class="AdminLessonList__day">Day {{ lesson.dayNumber }}</span>
      <span class="AdminLessonList__title">{{ lesson.title }}</span>
      <!-- edit / delete actions -->
    </div>
  </VueDraggable>
</template>
```

**Key constraint:** The `VueDraggable` component uses `v-model` to bind the list. The local list (`localLessons`) must be a writable ref — it cannot be a readonly computed from the store. The `@end` event fires after drop is complete. Send the full reordered ID array in one call (not individual PATCH calls).

**MVP fallback (if not installing vue-draggable-plus):** Up/down arrow buttons calling `reorderLessons` with the swapped order. This is simpler to build, has no library dependency, and satisfies the functional requirement without the UX polish of drag-and-drop.

---

### Anti-Patterns to Avoid

- **Forgetting `days` in create payload:** The `POST /api/programs` API requires `days` (number of days in the program). Groups had no equivalent field. The create form must include a `days` input. If omitted, the API will likely error or create an unusable program.
- **Using `orderedIds` key for reorder:** The reorder endpoint expects `{ "lessonOrder": [...] }` not `{ "orderedIds": [...] }`. This was an open question — now confirmed from Swift source.
- **Not re-fetching program after lesson delete:** `PATCH /api/programs/:id/lessons/:lessonId` returns only `{ success }` — no lesson back. `DELETE` also only returns `{ success }`. After delete, the remaining lessons' `dayNumber` values are reassigned by the API. Must call `getProgram(programId)` after delete to get the updated order. Failing to do so shows stale day numbers in the UI.
- **Skipping template load before opening create form:** If `loadTemplates()` is not awaited before the form opens, the template `select` renders empty. Load templates eagerly in `onMounted` on the programs list view.
- **Modifying the computed lessons list directly for drag:** vue-draggable-plus's `v-model` must bind to a writable `ref`, not a `computed`. Bind to a local `ref` copy synced from `detailUI.lessons` on load.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-and-drop list reorder | Custom mousedown/touchstart drag handlers | `vue-draggable-plus` with `VueDraggable` + `v-model` | SortableJS handles touch events, keyboard fallback, auto-scroll, animation; custom drag is 500+ lines |
| Delete confirmation modal | `window.confirm()` or custom overlay | `AdminConfirmDialog` (already built in Phase 6) | Already styled, focusable, uses reka-ui Dialog with focus trap |
| Programs list table | Custom table component | `AdminTable` (already built in Phase 6) | Already handles columns, rows, edit/delete emits, loading state, empty message |
| Create/edit form modal | Custom modal + fields | `AdminForm` (already built in Phase 6) | Already handles modal mode, inline mode, field types: text/textarea/toggle/number/select |
| Cover image upload | New upload component | `AdminImageUpload` (already built in Phase 6) | Already handles preview, FormData, `@upload` emit pattern |
| Tab chrome in detail view | Custom tab implementation | reka-ui `TabsRoot/TabsList/TabsTrigger/TabsContent` (used in groups-section.vue) | Already used; keyboard navigation, ARIA roles |

---

## Common Pitfalls

### Pitfall 1: `lessonOrder` key vs `orderedIds` — NOW RESOLVED

**Status:** Resolved. Key name is `lessonOrder`.
**Source:** `ProgramActions.swift` line 362: `let body: [String: Any] = ["lessonOrder": lessonIds]`

---

### Pitfall 2: PATCH Lesson Returns No Lesson Object

**What goes wrong:** After calling `PATCH /api/programs/:id/lessons/:lessonId` with `{ title }`, the UI shows the old lesson title because the domain store awaited an updated lesson in the response — but the API only returns `{ success: true }`.

**Why it happens:** The iPhone app (`updateLessonTitle` in ProgramActions.swift) calls the PATCH with just `{ "title": title }` and the response type is `APISuccessResponse` (no lesson field). The lesson title update is applied locally in iPhone state, not from the response.

**How to avoid:** After a successful title PATCH, update the lesson title directly in `programs.domain.ts`'s local `program.lessons` array. Do NOT try to parse a lesson from the response.

**Warning signs:** Lesson title appears unchanged after save. Refreshing the page shows the correct title (confirming API call worked).

---

### Pitfall 3: DELETE Lesson Causes Stale dayNumber Sequence

**What goes wrong:** Leader deletes Day 3 from a 5-day program. The UI still shows Days 1, 2, 4, 5 (gap in numbering) because the local lessons array was filtered by ID without re-fetching from the API.

**Why it happens:** The API reassigns `dayNumber` values server-side after deletion (e.g., Day 4 becomes Day 3). The local array filtered by `lessonId !== deletedId` still holds the old dayNumber values.

**How to avoid:** After `DELETE /api/programs/:id/lessons/:lessonId`, always re-fetch the full program with `getProgram(programId)`. This is exactly what the iPhone app does (ProgramActions.swift line 329: `_ = try await getProgram(id: programId)`).

**Warning signs:** Day numbers show a gap (1, 2, 4, 5) after deleting a lesson. Refreshing the page shows correct sequential numbers.

---

### Pitfall 4: Lesson Count in Programs List May Be Unavailable

**What goes wrong:** `PROG-01` requires showing lesson count in the programs list. If `GET /api/programs` does not include a lesson count in the list response (only `_count.enrollments` is confirmed), displaying "N lessons" is impossible without an extra API call per program.

**Why it happens:** `GET /api/programs` returns the program list. `GET /api/programs/:id` returns the program with its lessons. The list endpoint likely does not include all lessons for performance reasons.

**How to avoid:** Display lesson count as `—` in the programs list if the field is absent. Only show the count in the program detail view where `GET /api/programs/:id?lessonPage=1&lessonLimit=30` is called and lessons are included. This is an acceptable display limitation.

**Alternative:** Check if `program._count?.lessons` is present in the list response — `_count.enrollments` is confirmed present, `_count.lessons` may also be provided by Prisma's `_count` include. Test with the actual API. If `_count.lessons` exists, use it.

---

### Pitfall 5: vue-draggable-plus v-model Must Be a Writable Ref

**What goes wrong:** Binding `v-model="detailUI.lessons"` (a computed) to `VueDraggable` throws a Vue warning ("Set operation on key 'lessons' failed: target is readonly") and drag-and-drop does not update the list.

**Why it happens:** `detailUI.lessons` is a computed property — Vue computeds are read-only by default. `vue-draggable-plus` v-model requires a mutable ref to update the array on drag.

**How to avoid:** Declare a local `ref<Lesson[]>([])` in `programs-section.vue`. In `watch(detailUI.lessons, ...)`, sync it to the local ref. Bind `v-model` to the local ref. After `@end`, call `domain.reorderLessons()` with the new order.

**Warning signs:** Vue console warning about readonly target; drag visually works but list snaps back to original order.

---

### Pitfall 6: Programs Admin Route Not Yet Serving API Proxy for Lesson Endpoints

**What goes wrong:** `POST /admin/api/programs/:programId/lessons` returns HTML (the Blade shell) instead of JSON.

**Why it happens:** The existing `AdminApiProxyController` proxy route is:
```php
Route::match([...], '/api/{path}', ...)->where('path', '.*')
```
This should match `/api/programs/abc123/lessons`. However, the `{path}` wildcard with `.*` must correctly capture paths with multiple segments. Confirm this works for nested paths — it should because `.*` captures slashes.

**How to avoid:** Verify the proxy handles nested paths by running a test request for a programs lesson endpoint in `ProgramsAdminTest.php` during Wave 0. The existing `GroupsAdminTest.php` pattern covers this for verification.

---

## Code Examples

### Confirmed Reorder Request Body

```typescript
// Source: ProgramActions.swift line 362
// Key name is "lessonOrder" — CONFIRMED
await axios.post(`/admin/api/programs/${programId}/reorder-lessons`, {
  lessonOrder: lessonIds,  // string[] of lesson IDs in new order
})
// Response: { success: true, program: { ..., lessons: [...] } }
```

### Template Options in AdminForm Select Field

```typescript
// programs-section.vue — compute template options for select field
const createFields = computed(() => [
  { key: 'name', label: 'Program Name', type: 'text' as const, required: true },
  { key: 'description', label: 'Description', type: 'textarea' as const },
  {
    key: 'templateId',
    label: 'Template',
    type: 'select' as const,
    required: true,
    options: domain.templates.map(t => ({ value: t.id, label: t.name })),
  },
  { key: 'days', label: 'Number of Days', type: 'number' as const, required: true, placeholder: '30' },
])
```

### Publish Toggle via PATCH

```typescript
// In programs-section.vue — toggle publish state
async function handleTogglePublish(): Promise<void> {
  if (!detailUI.currentProgram) return
  const newState = !detailUI.currentProgram.isPublished
  await domain.updateProgram(detailUI.currentProgram.id, { isPublished: newState })
  // domain.updateProgram() already updates programs.value[idx] in place
}
```

### Lesson Delete with Re-fetch Pattern

```typescript
// In programs-section.vue — delete lesson and re-fetch program
async function handleDeleteLesson(): Promise<void> {
  const lesson = detailUI.confirmDeleteLesson
  if (!lesson) return
  try {
    await domain.deleteLesson(route.params.id as string, lesson.id)
    // domain.deleteLesson() calls getProgram() internally — dayNumbers updated
  } finally {
    detailUI.cancelDeleteLesson()
  }
}
```

### vue-draggable-plus Lesson List — Local Ref Pattern

```typescript
// In programs-section.vue detail section
import { VueDraggable } from 'vue-draggable-plus'
import { GripVertical } from 'lucide-vue-next'

const localLessons = ref<Lesson[]>([])

watch(
  () => detailUI.lessons,
  (newLessons) => {
    localLessons.value = [...newLessons]
  },
  { immediate: true }
)

async function handleLessonReorder(): Promise<void> {
  const ids = localLessons.value.map((l) => l.id)
  await domain.reorderLessons(route.params.id as string, ids)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `orderedIds` key (assumed) | `lessonOrder` key (confirmed) | Phase 7 research confirmed | Use `lessonOrder` in all reorder calls |
| Guess lesson count from list | Show `—` if not available; use `_count.lessons` if present | Phase 7 research | No extra API calls per program in list view |
| Rebuild lessons list on every drag event | Sync to local ref, send one POST on drop end | Phase 7 research | Avoids API thrashing during drag |
| Draft program delete shows plain confirm | `AdminConfirmDialog` with program name | Phase 6 established | Consistent dark-theme delete confirmation |

---

## Open Questions

1. **Is `_count.lessons` included in `GET /api/programs` list response?**
   - What we know: `_count.enrollments` is confirmed present (accessed in ProgramActions.swift). `_count` is a Prisma aggregate field included at query time.
   - What's unclear: Whether the server-side `GET /api/programs` query includes `_count: { select: { lessons: true } }` alongside enrollments.
   - Recommendation: Display `—` for lesson count in list view for safety. After the first API call, check the actual response shape in the browser and update if `_count.lessons` is present.

2. **Does `GET /api/programs` list include `isPublished` field?**
   - What we know: `updateProgram` in ProgramActions.swift sends `isPublished` as a PATCH field. The `StudyProgram` Swift type should have it.
   - What's unclear: Whether it's included in the list endpoint response (it should be — it's a core program field, not a count).
   - Recommendation: Assume yes (treat as HIGH confidence). If the field is missing in the list response, fetch it from the single-program response in detail view only.

3. **What does `days` represent exactly in `POST /api/programs`?**
   - What we know: The create payload requires `days: Int`. ProgramActions.swift line 170 shows `"days": days` in the request body. The iPhone create-program flow prompts for this.
   - What's unclear: Whether `days` pre-generates N empty lessons or is just metadata. The API may auto-create N lessons on program create.
   - Recommendation: Default to `0` in the create form (no pre-generated lessons) and let leaders add lessons manually. If `days: 0` errors, try `days: 1`. Document the behavior after first successful create.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel feature tests) |
| Config file | `phpunit.xml` |
| Quick run command | `php artisan test tests/Feature/ProgramsAdminTest.php` |
| Full suite command | `php artisan test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROG-01 | GET /admin/api/programs proxied to external API with programs array | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_programs_list_proxy` | ❌ Wave 0 |
| PROG-02 | POST /admin/api/programs with name+templateId+days forwarded as JSON | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_create_program_proxy` | ❌ Wave 0 |
| PROG-03 | PATCH /admin/api/programs/:id with name/description forwarded | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_update_program_proxy` | ❌ Wave 0 |
| PROG-04 | POST /admin/api/programs/:id/cover-image forwards multipart file | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_cover_image_upload_proxy` | ❌ Wave 0 |
| PROG-05 | PATCH /admin/api/programs/:id with isPublished toggles publish state | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_toggle_publish_proxy` | ❌ Wave 0 |
| PROG-06 | DELETE /admin/api/programs/:id proxied and returns success | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_delete_program_proxy` | ❌ Wave 0 |
| PROG-07 | GET /admin/programs/:id returns 200 with AdminIsland mount | smoke | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_program_detail_renders` | ❌ Wave 0 |
| LSSN-01 | GET /admin/api/programs/:id with lesson params proxied correctly | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_get_program_with_lessons_proxy` | ❌ Wave 0 |
| LSSN-02 | POST /admin/api/programs/:id/lessons with empty body proxied | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_add_lesson_proxy` | ❌ Wave 0 |
| LSSN-03 | PATCH /admin/api/programs/:id/lessons/:lessonId with title proxied | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_update_lesson_title_proxy` | ❌ Wave 0 |
| LSSN-04 | DELETE /admin/api/programs/:id/lessons/:lessonId proxied and returns success | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_delete_lesson_proxy` | ❌ Wave 0 |
| LSSN-05 | POST /admin/api/programs/:id/reorder-lessons with lessonOrder array proxied | integration | `php artisan test tests/Feature/ProgramsAdminTest.php --filter test_reorder_lessons_proxy` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `php artisan test tests/Feature/ProgramsAdminTest.php`
- **Per wave merge:** `php artisan test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/Feature/ProgramsAdminTest.php` — covers PROG-01 through PROG-07 and LSSN-01 through LSSN-05
  - Follows `GroupsAdminTest.php` pattern exactly: `Http::fake()` per test, `fakeSession()` shared helper
  - PROG-04 test uses `UploadedFile::fake()->image('cover.jpg', 800, 600)->size(2000)` (same as GRP-05)
  - LSSN-05 test verifies proxy receives `lessonOrder` key in request body
  - GET /admin/api/templates must be faked in PROG-02 test (required for template selector load)

*(No framework install gaps — PHPUnit is installed and running.)*

---

## Sources

### Primary (HIGH confidence)

- `/iphone/MakeReady/State/Actions/ProgramActions.swift` — authoritative API endpoint surface for all program/lesson operations; all request body shapes and response shapes confirmed by direct inspection
  - PROG-01: `fetchPrograms()` — `GET /api/programs`, response `{ success, programs }`
  - PROG-02: `createProgram()` — `POST /api/programs` body: `name`, `templateId`, `days`, `isPublished`, `description`
  - PROG-03/05: `updateProgram()` — `PATCH /api/programs/:id` body: all optional fields including `isPublished`
  - PROG-04: `uploadCoverImage()` — `POST /api/programs/:id/cover-image` multipart, response `{ success, coverImageUrl }`
  - PROG-06: `deleteProgram()` — `DELETE /api/programs/:id`, response `{ success }`
  - LSSN-01: `getProgram()` — `GET /api/programs/:id?lessonPage=N&lessonLimit=N`
  - LSSN-02: `addLesson()` — `POST /api/programs/:id/lessons` body `{}`, response `{ success, lesson }`
  - LSSN-03: `updateLessonTitle()` — `PATCH /api/programs/:id/lessons/:lessonId` body `{ title }`, response `APISuccessResponse` (no lesson object)
  - LSSN-04: `deleteLesson()` — `DELETE /api/programs/:id/lessons/:lessonId`, then re-fetches program
  - LSSN-05: `reorderLessons()` — `POST /api/programs/:id/reorder-lessons` body `{ "lessonOrder": [ids] }` (CONFIRMED key name)
  - Templates: `fetchTemplates()` — `GET /api/templates`, response `{ success, templates }`
- `/client/resources/js/islands/admin-island/sections/groups-section.vue` — established orchestrator pattern for list/detail branching, tab usage, store consumption
- `/client/resources/js/islands/admin-island/stores/domain/groups.domain.ts` — established domain store pattern; programs.domain.ts mirrors this exactly
- `/client/resources/js/components/admin/admin-form/admin-form.vue` — confirmed `select` field type is implemented; `toggle` field type is implemented; `inline` and `hideCancelButton` props available
- `/client/resources/js/islands/admin-island/router.ts` — confirmed `/admin/programs` and `/admin/programs/:id` routes pre-registered
- `/client/tests/Feature/GroupsAdminTest.php` — test pattern for proxy testing; ProgramsAdminTest.php follows this verbatim
- `/client/resources/css/app.scss` — confirmed admin-tabs.scss already imported; programs-specific lesson list SCSS follows same registration pattern

### Secondary (MEDIUM confidence)

- vue-draggable-plus GitHub (https://github.com/Alfred-Skyblue/vue-draggable-plus) — `VueDraggable` component, `v-model` API, `@end` event, `handle` prop confirmed from documentation and last updated January 2026
- `.planning/research/SUMMARY.md` — `vue-draggable-plus 0.6.1` confirmed as recommended library for Phase 7 drag-and-drop
- `.planning/research/FEATURES.md` — API surface table confirms all program endpoints

### Tertiary (LOW confidence)

- `_count.lessons` field availability in GET /api/programs list response — not confirmed from ProgramActions.swift; inferred from Prisma `_count` pattern where `_count.enrollments` is confirmed; treat as unconfirmed

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| API endpoints | HIGH | All endpoints confirmed directly from ProgramActions.swift with exact request/response shapes |
| Reorder key name | HIGH | `lessonOrder` confirmed from ProgramActions.swift line 362 — was a known uncertainty, now resolved |
| Proxy controller | HIGH | Existing AdminApiProxyController handles nested paths via `.*` wildcard; confirmed from GroupsAdminTest.php tests |
| Pinia store pattern | HIGH | Direct copy of groups.domain.ts + groups-list.ui.ts pattern with program-specific fields |
| vue-draggable-plus | MEDIUM | Package exists and is maintained; `VueDraggable` component API confirmed from docs; not yet tested in this codebase |
| Lesson count in list | LOW | `_count.lessons` not confirmed in list response; safe default is to show `—` |
| `days` field semantics | LOW | Required by API but exact behavior (pre-generate lessons vs metadata) not confirmed |

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (API stable; stack stable; vue-draggable-plus unlikely to break)
