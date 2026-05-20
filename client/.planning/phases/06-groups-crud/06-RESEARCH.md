# Phase 6: Groups CRUD - Research

**Researched:** 2026-03-19
**Domain:** Vue 3 + Pinia CRUD with Laravel API proxy — groups entity
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| GRP-01 | Leader can view a list of all groups with name, cover image, member count, and privacy status | `GET /api/groups` confirmed; response shape: `{ success, groups: [...] }` — each group has `id`, `name`, `coverImageUrl`, `isPrivate`, plus `memberCount` inferred from member list length or API-provided field |
| GRP-02 | Leader can create a new group (name, description) | `POST /api/groups` confirmed from GroupActions.swift; required fields: `name`; optional: `description`, `isPrivate`, `allowInvites`, `memberDirectory` |
| GRP-03 | Leader can edit group metadata (name, description, welcome message) | `PATCH /api/groups/:id` confirmed; accepts all fields as partials; response: `{ success, group }` |
| GRP-04 | Leader can edit group settings (privacy, allow invites, member directory, age range, max members) | Same `PATCH /api/groups/:id` endpoint handles all settings fields; `ageRange` is an object `{ min?, max? }` |
| GRP-05 | Leader can upload/change a group cover image | `POST /api/groups/:id/cover-image` confirmed; multipart upload; response: `{ success, coverImageUrl }` |
| GRP-06 | Leader can delete a group (with confirmation) | `DELETE /api/groups/:id` confirmed; returns `{ success }` |
| GRP-07 | Group detail view has tabs for Members, Enrollments, Posts, and Settings | Tab strip UI with reka-ui Tabs; only the tab chrome built this phase — tab content panels are stubs for Phases 9+ |
</phase_requirements>

---

## Summary

Phase 6 builds the complete Groups CRUD feature inside the existing AdminIsland — the first real entity domain after the shell built in Phase 5. The primary deliverables are: a groups list table with create/edit/delete actions, a group settings form (metadata + settings in one PATCH call), multipart cover image upload, a delete-confirm dialog, and a group detail view with a four-tab chrome (Members, Enrollments, Posts, Settings) where tab panels show placeholder content.

This phase establishes three reusable patterns that every subsequent entity phase (Programs, Enrollments, Members) will copy verbatim: the Pinia domain store pattern (`groups.domain.ts`), the admin table component (`AdminTable`), and the admin form component (`AdminForm`). Getting these patterns right here prevents rework in Phases 7–9. The tab chrome also sets the precedent for Programs tabs.

Cover image upload uses multipart `FormData` posted to the Laravel proxy, which calls `ApiService::upload()`. This is the first image upload in the admin surface — it must be done correctly (multipart, not base64) because Programs follow the same pattern.

**Primary recommendation:** Build `groups.domain.ts` and `groups-list.ui.ts` first. Stand up the groups list with stubbed CRUD. Then add the form modal. Then cover image. Then group detail with tab stubs. This order ensures each piece is independently shippable and testable.

---

## Standard Stack

### Core (all already installed — no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.30 | Component framework | Installed, single AdminIsland |
| Pinia | 3.0.4 | State management | Installed, composition API style |
| Vue Router | 4.6.4 | Client-side routing | Installed, Phase 5 established history-mode router |
| axios | 1.11.0 | HTTP client | Installed, CSRF configured in AdminIsland onMounted |
| reka-ui | 2.9.2 | Headless UI primitives (Tabs, Dialog) | Installed, confirmed to have Tabs and Dialog components |
| lucide-vue-next | 0.577.0 | Icons | Installed, used in AdminSidebar |
| histoire | 0.17.17 | Component stories | Installed, all new admin components need stories |

### No New Dependencies

This phase requires zero new npm installs. All capabilities are available in the existing stack:
- **Tabs:** reka-ui `TabsRoot`, `TabsList`, `TabsTrigger`, `TabsContent`
- **Delete confirm dialog:** reka-ui `DialogRoot`, `DialogTrigger`, `DialogContent` (or a simple modal using the existing modal store)
- **Image upload:** Native `<input type="file">` + `FormData` + axios
- **Form validation:** HTML5 constraint validation (`required`, `maxlength`) + reactive `ref` for errors

---

## Architecture Patterns

### Recommended File Structure (Phase 6 additions)

```
resources/
├── js/
│   ├── islands/admin-island/
│   │   ├── sections/
│   │   │   └── groups-section.vue          ← REWRITE (stub → real implementation)
│   │   ├── stores/
│   │   │   ├── domain/
│   │   │   │   └── groups.domain.ts         ← NEW
│   │   │   └── ui/
│   │   │       ├── groups-list.ui.ts        ← NEW
│   │   │       └── group-detail.ui.ts       ← NEW
│   │   └── components/
│   │       └── (admin-sidebar.vue exists)
│   └── components/
│       └── admin/                           ← NEW folder (first admin display components)
│           ├── admin-table/
│           │   ├── admin-table.vue
│           │   └── admin-table.story.vue
│           ├── admin-form/
│           │   ├── admin-form.vue
│           │   └── admin-form.story.vue
│           ├── admin-image-upload/
│           │   ├── admin-image-upload.vue
│           │   └── admin-image-upload.story.vue
│           └── admin-confirm-dialog/
│               ├── admin-confirm-dialog.vue
│               └── admin-confirm-dialog.story.vue
├── css/
│   └── components/
│       └── admin/                           ← NEW folder
│           ├── admin-table.scss
│           ├── admin-form.scss
│           ├── admin-image-upload.scss
│           └── admin-confirm-dialog.scss
└── app/Http/Controllers/
    └── AdminApiProxyController.php          ← NEW
```

Also add to `routes/web.php` (before the admin catch-all):
```
Route::match(['GET','POST','PATCH','PUT','DELETE'], 'admin/api/{path}', ...)
```

Also import new SCSS files in `app.scss` under the `// Admin components` section.

---

### Pattern 1: Groups Domain Store

**What:** `groups.domain.ts` owns all raw API calls for groups entity. Returns API data, stores it in reactive refs, exposes typed async methods. Never transforms data for display.

**Source:** Directly follows the `programs.domain.ts` template from ARCHITECTURE.md, adapted for groups endpoints confirmed in GroupActions.swift.

```typescript
// resources/js/islands/admin-island/stores/domain/groups.domain.ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import axios from 'axios'

export interface Group {
  id: string
  name: string
  description?: string
  coverImageUrl?: string
  isPrivate: boolean
  allowInvites: boolean
  memberDirectory: boolean
  welcomeMessage?: string
  ageRange?: { min?: number; max?: number }
  maxMembers?: number
  memberCount?: number
}

export interface CreateGroupPayload {
  name: string
  description?: string
  isPrivate?: boolean
  allowInvites?: boolean
  memberDirectory?: boolean
}

export interface UpdateGroupPayload {
  name?: string
  description?: string
  isPrivate?: boolean
  allowInvites?: boolean
  memberDirectory?: boolean
  welcomeMessage?: string
  ageRange?: { min?: number; max?: number }
  maxMembers?: number
}

export const useGroupsDomain = defineStore('groups-domain', () => {
  const groups = ref<Group[]>([])
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  async function loadGroups(): Promise<void> {
    isLoading.value = true
    error.value = null
    try {
      const res = await axios.get('/admin/api/groups')
      groups.value = res.data.groups ?? []
    } catch (e: any) {
      error.value = e.response?.data?.error ?? 'Failed to load groups'
    } finally {
      isLoading.value = false
    }
  }

  async function getGroup(id: string): Promise<Group> {
    const res = await axios.get(`/admin/api/groups/${id}`)
    const group: Group = res.data.group
    const idx = groups.value.findIndex(g => g.id === id)
    if (idx >= 0) groups.value[idx] = group
    else groups.value.push(group)
    return group
  }

  async function createGroup(payload: CreateGroupPayload): Promise<Group> {
    const res = await axios.post('/admin/api/groups', payload)
    const group: Group = res.data.group
    groups.value.push(group)
    return group
  }

  async function updateGroup(id: string, payload: UpdateGroupPayload): Promise<Group> {
    const res = await axios.patch(`/admin/api/groups/${id}`, payload)
    const updated: Group = res.data.group
    const idx = groups.value.findIndex(g => g.id === id)
    if (idx >= 0) groups.value[idx] = updated
    return updated
  }

  async function deleteGroup(id: string): Promise<void> {
    await axios.delete(`/admin/api/groups/${id}`)
    groups.value = groups.value.filter(g => g.id !== id)
  }

  async function uploadCoverImage(id: string, file: File): Promise<string> {
    const formData = new FormData()
    formData.append('image', file)
    const res = await axios.post(`/admin/api/groups/${id}/cover-image`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    })
    const url: string = res.data.coverImageUrl
    const idx = groups.value.findIndex(g => g.id === id)
    if (idx >= 0) groups.value[idx] = { ...groups.value[idx], coverImageUrl: url }
    return url
  }

  return { groups, isLoading, error, loadGroups, getGroup, createGroup, updateGroup, deleteGroup, uploadCoverImage }
})
```

**Confidence:** HIGH — all endpoints verified from GroupActions.swift.

---

### Pattern 2: Groups List UI Store

**What:** `groups-list.ui.ts` consumes `groups.domain.ts` and computes exactly the props that `groups-section.vue` and `AdminTable` need. Owns form open/close state and navigates to group detail.

```typescript
// resources/js/islands/admin-island/stores/ui/groups-list.ui.ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { useGroupsDomain } from '../domain/groups.domain'
import { useRouter } from 'vue-router'

export interface AdminTableRow {
  id: string
  cells: string[]
  coverImageUrl?: string
  badge?: string
}

export const useGroupsListUI = defineStore('groups-list-ui', () => {
  const domain = useGroupsDomain()
  const router = useRouter()

  const isCreateFormOpen = ref(false)
  const editingGroupId = ref<string | null>(null)
  const confirmDeleteId = ref<string | null>(null)
  const formError = ref<string | null>(null)

  const tableRows = computed<AdminTableRow[]>(() =>
    domain.groups.map(g => ({
      id: g.id,
      cells: [
        g.name,
        g.memberCount != null ? `${g.memberCount} members` : '—',
        g.isPrivate ? 'Private' : 'Public',
      ],
      coverImageUrl: g.coverImageUrl,
      badge: g.isPrivate ? 'Private' : undefined,
    }))
  )

  const editingGroup = computed(() =>
    editingGroupId.value ? domain.groups.find(g => g.id === editingGroupId.value) ?? null : null
  )

  const confirmDeleteGroup = computed(() =>
    confirmDeleteId.value ? domain.groups.find(g => g.id === confirmDeleteId.value) ?? null : null
  )

  function openCreateForm() {
    editingGroupId.value = null
    formError.value = null
    isCreateFormOpen.value = true
  }

  function openEditForm(id: string) {
    editingGroupId.value = id
    formError.value = null
    isCreateFormOpen.value = true
  }

  function closeForm() {
    isCreateFormOpen.value = false
    editingGroupId.value = null
    formError.value = null
  }

  function requestDelete(id: string) {
    confirmDeleteId.value = id
  }

  function cancelDelete() {
    confirmDeleteId.value = null
  }

  function navigateToDetail(id: string) {
    router.push(`/admin/groups/${id}`)
  }

  return {
    tableRows,
    isCreateFormOpen,
    editingGroup,
    confirmDeleteGroup,
    formError,
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

### Pattern 3: Groups Section Component (Orchestrator)

**What:** `groups-section.vue` is the ONLY component that imports Pinia stores and calls domain store methods. It catches events from pure display components and translates them into store calls. Uses `useRoute` to detect list vs detail view.

```vue
<!-- resources/js/islands/admin-island/sections/groups-section.vue -->
<script setup lang="ts">
import { onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useGroupsDomain } from '../stores/domain/groups.domain'
import { useGroupsListUI } from '../stores/ui/groups-list.ui'
import AdminTable from '../../../components/admin/admin-table/admin-table.vue'
import AdminForm from '../../../components/admin/admin-form/admin-form.vue'
import AdminConfirmDialog from '../../../components/admin/admin-confirm-dialog/admin-confirm-dialog.vue'

const route = useRoute()
const domain = useGroupsDomain()
const listUI = useGroupsListUI()

onMounted(async () => {
  if (!route.params.id) {
    await domain.loadGroups()
  } else {
    await domain.getGroup(route.params.id as string)
  }
})

async function handleCreate(payload: Record<string, any>) {
  try {
    await domain.createGroup(payload as any)
    listUI.closeForm()
  } catch (e: any) {
    listUI.formError.value = e.response?.data?.error ?? 'Failed to create group'
  }
}

async function handleUpdate(payload: Record<string, any>) {
  try {
    await domain.updateGroup(listUI.editingGroup!.id, payload as any)
    listUI.closeForm()
  } catch (e: any) {
    listUI.formError.value = e.response?.data?.error ?? 'Failed to update group'
  }
}

async function handleDelete(id: string) {
  try {
    await domain.deleteGroup(id)
    listUI.cancelDelete()
  } catch (e: any) {
    // surface error — keep dialog open
  }
}
</script>
```

---

### Pattern 4: Admin API Proxy Controller (NEW — required before any CRUD works)

**What:** `AdminApiProxyController.php` is a thin Laravel controller that receives all `/admin/api/{path}` requests, forwards them to the external API via `ApiService`, and returns JSON. Must be registered BEFORE the admin catch-all route in `routes/web.php`.

```php
// app/Http/Controllers/AdminApiProxyController.php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\ApiService;

class AdminApiProxyController extends Controller
{
    public function __construct(private ApiService $api) {}

    public function handle(Request $request, string $path): \Illuminate\Http\JsonResponse
    {
        $endpoint = '/api/' . $path;
        $query = $request->getQueryString();
        if ($query) $endpoint .= '?' . $query;

        $result = match (strtolower($request->method())) {
            'get'    => $this->api->get($endpoint, $request),
            'post'   => $this->handlePost($request, $endpoint),
            'patch'  => $this->api->patch($endpoint, $request->json()->all(), $request),
            'delete' => $this->api->delete($endpoint, $request),
            default  => ['status' => 405, 'body' => ['error' => 'Method not allowed'], 'setCookies' => []],
        };

        $response = response()->json($result['body'], $result['status']);
        foreach ($result['setCookies'] as $cookie) {
            $response->headers->set('Set-Cookie', $cookie, false);
        }
        return $response;
    }

    private function handlePost(Request $request, string $endpoint): array
    {
        // Detect multipart (cover image uploads)
        if ($request->hasFile('image')) {
            $file = $request->file('image');
            return $this->api->upload($endpoint, 'image', $file, $request);
        }
        return $this->api->post($endpoint, $request->json()->all() ?? [], $request);
    }
}
```

**Route registration** — add BEFORE the `/{any?}` catch-all in the admin group:

```php
Route::middleware('member.auth')->prefix('admin')->name('admin.')->group(function () {
    // API proxy — must come before the catch-all Blade route
    Route::match(
        ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
        '/api/{path}',
        [AdminApiProxyController::class, 'handle']
    )->where('path', '.*')->name('api.proxy');

    // SPA shell catch-all — serves AdminIsland for all /admin/* page routes
    Route::get('/{any?}', [AdminController::class, 'show'])
        ->where('any', '.*')
        ->name('shell');
});
```

**Confidence:** HIGH — this pattern follows the architecture established in ARCHITECTURE.md; `ApiService` already has all required methods including `delete()` and `upload()`.

---

### Pattern 5: Admin Table Component (Reusable)

**What:** Pure display component. Receives typed rows and column headers via props. Emits `@row-click`, `@edit`, `@delete`. No store access. Reused by Programs, Members, Enrollments.

```typescript
// Props contract
interface AdminTableRow {
  id: string
  cells: string[]          // rendered in order matching columns
  coverImageUrl?: string   // shown as thumbnail in first cell if present
  badge?: string           // optional status badge
}

interface Props {
  columns: string[]        // ['Name', 'Members', 'Privacy']
  rows: AdminTableRow[]
  loading?: boolean
  emptyMessage?: string
}

// Emits
defineEmits<{
  'row-click': [id: string]
  'edit': [id: string]
  'delete': [id: string]
}>()
```

BEM class root: `AdminTable`. SCSS file: `resources/css/components/admin/admin-table.scss`.

---

### Pattern 6: Admin Form Component (Reusable)

**What:** Pure display component. Receives a list of field definitions and current values via props. Emits `@save` with payload, `@cancel`. Handles its own inline validation display. No store access.

```typescript
interface FormField {
  key: string
  label: string
  type: 'text' | 'textarea' | 'toggle' | 'number' | 'select'
  required?: boolean
  placeholder?: string
  options?: { value: any; label: string }[]  // for select type
}

interface Props {
  title: string
  fields: FormField[]
  values: Record<string, any>   // initial values
  error?: string                // external error from store
  saving?: boolean
}

defineEmits<{
  save: [payload: Record<string, any>]
  cancel: []
}>()
```

BEM class root: `AdminForm`. Fields rendered as standard HTML inputs styled with BEM. No reka-ui dependency inside the form itself — reka-ui Dialog is used as the modal container wrapping `AdminForm`.

---

### Pattern 7: Admin Confirm Dialog Component (Reusable)

**What:** Pure display component for delete confirmation. Receives entity name for personalised message. Emits `@confirm`, `@cancel`. Wraps reka-ui `DialogRoot`.

```typescript
interface Props {
  open: boolean
  title: string         // 'Delete Group'
  message: string       // 'Are you sure you want to delete "Alpha Group"? This cannot be undone.'
  confirmLabel?: string // default 'Delete'
  dangerous?: boolean   // default true — styles confirm button red
}

defineEmits<{
  confirm: []
  cancel: []
}>()
```

BEM class root: `AdminConfirmDialog`.

---

### Pattern 8: Admin Image Upload Component (Reusable)

**What:** Pure display component. Shows current image (or placeholder), file input, and upload progress. Emits `@upload` with the `File` object — parent section calls domain store's `uploadCoverImage`. No axios in the component.

```typescript
interface Props {
  currentUrl?: string
  uploading?: boolean
  label?: string         // 'Cover Image'
  accept?: string        // 'image/*'
  maxSizeMb?: number     // for client-side validation message; actual limit enforced by PHP
}

defineEmits<{
  upload: [file: File]
}>()
```

BEM class root: `AdminImageUpload`.

---

### Pattern 9: Group Detail View with Tab Chrome

**What:** When `route.params.id` is present in `groups-section.vue`, render the group detail layout with reka-ui Tabs. Tab panels for Members, Enrollments, Posts, and Settings are stubs in this phase. Settings tab shows the group settings form (editable). The other three show placeholder text.

**Tab implementation with reka-ui:**

```vue
<!-- Tabs usage within groups-section.vue detail branch -->
<TabsRoot default-value="members">
  <TabsList class="AdminTabs__list">
    <TabsTrigger value="members" class="AdminTabs__trigger">Members</TabsTrigger>
    <TabsTrigger value="enrollments" class="AdminTabs__trigger">Enrollments</TabsTrigger>
    <TabsTrigger value="posts" class="AdminTabs__trigger">Posts</TabsTrigger>
    <TabsTrigger value="settings" class="AdminTabs__trigger">Settings</TabsTrigger>
  </TabsList>
  <TabsContent value="members" class="AdminTabs__content">
    <p>Members — coming in Phase 9</p>
  </TabsContent>
  <TabsContent value="enrollments" class="AdminTabs__content">
    <p>Enrollments — coming in Phase 9</p>
  </TabsContent>
  <TabsContent value="posts" class="AdminTabs__content">
    <p>Posts — coming in Phase 9</p>
  </TabsContent>
  <TabsContent value="settings" class="AdminTabs__content">
    <!-- Settings form using AdminForm component -->
    <AdminForm
      title="Group Settings"
      :fields="settingsFields"
      :values="groupDetailUI.settingsValues"
      :error="settingsError"
      :saving="isSaving"
      @save="handleSettingsSave"
      @cancel="() => {}"
    />
  </TabsContent>
</TabsRoot>
```

BEM class root for tab chrome: `AdminTabs`. SCSS: `resources/css/components/admin/admin-tabs.scss`.

**Import path for reka-ui Tabs:**
```typescript
import { TabsRoot, TabsList, TabsTrigger, TabsContent } from 'reka-ui'
```
Source: reka-ui 2.x (installed). Confirmed present in the package.

---

### Pattern 10: Group Detail UI Store

**What:** `group-detail.ui.ts` consumes `groups.domain.ts` to compute display props for the selected group. Owns the active tab state.

```typescript
export const useGroupDetailUI = defineStore('group-detail-ui', () => {
  const domain = useGroupsDomain()
  const route = useRoute()

  const activeTab = ref('members')

  const currentGroup = computed(() =>
    domain.groups.find(g => g.id === route.params.id) ?? null
  )

  const settingsFormValues = computed(() => {
    const g = currentGroup.value
    if (!g) return {}
    return {
      name: g.name,
      description: g.description ?? '',
      welcomeMessage: g.welcomeMessage ?? '',
      isPrivate: g.isPrivate,
      allowInvites: g.allowInvites,
      memberDirectory: g.memberDirectory,
      maxMembers: g.maxMembers ?? null,
    }
  })

  return { activeTab, currentGroup, settingsFormValues }
})
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tab strip UI | Custom tab implementation with v-show | reka-ui `TabsRoot/TabsList/TabsTrigger/TabsContent` | Already installed; handles keyboard navigation, ARIA roles, accessible selection state |
| Delete confirm dialog | `window.confirm()` or custom overlay | reka-ui `DialogRoot/DialogContent` wrapping `AdminConfirmDialog` component | `window.confirm()` blocks the thread and can't be styled; reka-ui Dialog handles focus trap, ESC key, scroll lock |
| Form field validation | Custom regex validators | HTML5 `required`, `minlength`, `type="url"` constraints + form `checkValidity()` | Browser-native validation is sufficient for admin fields; custom validators add complexity without value |
| Image preview | FileReader.readAsDataURL manually | `URL.createObjectURL(file)` + revoke on component unmount | `createObjectURL` is synchronous, memory-efficient, and avoids base64 string allocation |
| Reactive form state | Manual v-model per field | Single `formValues` ref object `{}` populated from field definitions | Consistent approach that works for both create (empty) and edit (prefilled) without separate code paths |

---

## Common Pitfalls

### Pitfall 1: Admin API Proxy Route Order

**What goes wrong:** Vue Router client-side navigation to `/admin/groups` resolves on the browser. But an axios `GET /admin/api/groups` request hits Laravel routing. If the proxy route is registered AFTER the `/{any?}` catch-all, Laravel's Blade catch-all intercepts the API request and returns HTML instead of JSON — Vue gets a 200 with HTML body, `res.data` is not an array.

**Why it happens:** Laravel route matching is first-match. The existing catch-all `Route::get('/{any?}', ...)` with `->where('any', '.*')` matches ALL GET paths including `/admin/api/groups`.

**How to avoid:** Register `Route::match(['GET','POST','PATCH','PUT','DELETE'], '/api/{path}', ...)` BEFORE the `/{any?}` line in the admin route group. Verify with a `php artisan route:list` check.

**Warning signs:** `res.data` is a string starting with `<!DOCTYPE html>`. All axios calls to `/admin/api/*` return 200 with HTML bodies.

---

### Pitfall 2: Multipart vs JSON for Cover Image

**What goes wrong:** Sending the image file as base64 JSON (`{ image: 'data:image/jpeg;base64,...' }`) in a `Content-Type: application/json` POST fails silently or 500s on large files. PHP's default `upload_max_filesize` is 2MB; a 4MB JPEG encoded as base64 is ~5.3MB.

**Why it happens:** Base64 inflates file size by ~33%. When the encoded string exceeds PHP memory limits, the request is silently dropped or returns a 500 with no useful error.

**How to avoid:** Always use `FormData` with `formData.append('image', file)` and set `Content-Type: multipart/form-data` on the axios request. The `AdminApiProxyController` must detect `$request->hasFile('image')` and call `$this->api->upload()` instead of `$this->api->post()`.

**Warning signs:** Small test images (< 100KB) upload fine, real photos (3–5MB) silently fail or return 500.

---

### Pitfall 3: Stale Groups List After Mutation

**What goes wrong:** After creating, updating, or deleting a group, the table still shows the old data because the domain store's `groups` array was not updated.

**Why it happens:** If the CRUD methods call the API but don't update `groups.value`, the reactive array is stale. The UI store's `tableRows` computed re-renders only when the underlying `groups` array changes.

**How to avoid:** Domain store methods must optimistically update `groups.value`:
- `createGroup`: push the returned group to `groups.value`
- `updateGroup`: splice-replace in `groups.value` by id
- `deleteGroup`: filter out the deleted id from `groups.value`

All three patterns are shown in the domain store example above.

**Warning signs:** After creating a group, returning to the list shows the old set. Refreshing the page shows the new group (confirming the API call worked).

---

### Pitfall 4: Form Modal State Bleed Between Create and Edit

**What goes wrong:** Leader opens the create form, partially fills it in, then cancels. Then opens edit for a different group. The form shows partially-filled create fields mixed with the group's actual data.

**Why it happens:** `AdminForm` receives `values` prop as initial state but uses internal `ref` for the editing copy. If the parent does not reset the `values` prop between uses, the form's internal state persists.

**How to avoid:** Use Vue's `:key` directive to force component remount when switching between create and edit modes:
```vue
<AdminForm
  :key="editingGroupId ?? 'create'"
  :values="editingGroup ? editingGroup : {}"
  ...
/>
```
Changing the key forces Vue to destroy and recreate the `AdminForm`, resetting all internal refs.

**Warning signs:** Edit form pre-fills with wrong data. Creating after editing shows previous group's values.

---

### Pitfall 5: Delete Confirmation Dialog Not Closing After Error

**What goes wrong:** Leader clicks "Delete", API returns an error, but the dialog stays in loading state and the user cannot dismiss it.

**Why it happens:** If the `deleteGroup` call throws and there is no error handler, `confirmDeleteId` is never reset to `null`, leaving the dialog open but frozen.

**How to avoid:** The `handleDelete` function in `groups-section.vue` must always call `listUI.cancelDelete()` in both the success and failure branches (or in a `finally` block). Surface error separately from the dialog state:
```typescript
async function handleDelete(id: string) {
  try {
    await domain.deleteGroup(id)
  } catch (e) {
    deleteError.value = 'Failed to delete group'
  } finally {
    listUI.cancelDelete()
  }
}
```

---

### Pitfall 6: reka-ui Dialog Teleport Conflicts

**What goes wrong:** The reka-ui Dialog overlays render inside the sidebar layout instead of at the `<body>` level, causing z-index issues where the sidebar appears on top of the modal overlay.

**Why it happens:** reka-ui Dialog content by default Teleports to `<body>`. But if the admin Blade template has a `<div id="app">` wrapper and the Vue island is mounted inside it, the Teleport target may be that wrapper rather than `<body>`. The existing member-experience modals use Teleport to `'body'` explicitly (confirmed in `navigation-island.vue`).

**How to avoid:** Confirm that reka-ui 2.x Dialogs Teleport to `<body>` by default (they do — documented behavior). If the overlay appears inside the island, add `to="body"` prop to the `DialogPortal`. Since the existing `AdminLayout` sets `overflow: hidden` on the sidebar, Teleporting to body is critical.

---

### Pitfall 7: Groups API Endpoint Returns Leader's Groups Only

**What goes wrong:** `GET /api/groups` is called but returns an empty list even though the leader has groups.

**Why it happens:** The API's `GET /api/groups` returns groups authenticated by `connect.sid`. If the proxy is not correctly forwarding the `connect.sid` cookie, the API treats the request as unauthenticated and returns either an error or an empty list.

**How to avoid:** `ApiService::extractApiCookies()` already handles this correctly — it filters for `connect.sid` only. The key risk is the proxy route middleware: it must use `member.auth` middleware (which runs `CheckMemberSession` and establishes `connect.sid` in the session). Confirmed: the admin route group already uses `member.auth`.

**Warning signs:** Proxy returns 401 or `{ success: false }` for group endpoints; member-facing pages load fine.

---

## Code Examples

### Image Upload via FormData to Proxy

```typescript
// In groups.domain.ts — uploadCoverImage()
// Source: ApiService.php upload() method signature
async function uploadCoverImage(id: string, file: File): Promise<string> {
  const formData = new FormData()
  formData.append('image', file)   // key must match ApiService upload($endpoint, 'image', ...)

  const res = await axios.post(`/admin/api/groups/${id}/cover-image`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
    // DO NOT set Content-Type manually if using FormData — axios sets it with boundary
    // The line above is actually not needed; axios handles multipart boundary automatically
  })
  return res.data.coverImageUrl
}
```

Note: Actually drop the explicit `Content-Type` header when using `FormData` with axios. Axios sets it automatically WITH the boundary string. Setting it manually will break the boundary.

**Corrected:**
```typescript
const res = await axios.post(`/admin/api/groups/${id}/cover-image`, formData)
// axios sets Content-Type: multipart/form-data; boundary=... automatically
```

### URL.createObjectURL for Image Preview

```typescript
// In admin-image-upload.vue — local preview before upload
const previewUrl = ref<string | null>(props.currentUrl ?? null)
let objectUrl: string | null = null

function handleFileChange(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return

  // Revoke previous object URL to avoid memory leak
  if (objectUrl) URL.revokeObjectURL(objectUrl)

  objectUrl = URL.createObjectURL(file)
  previewUrl.value = objectUrl
  emit('upload', file)
}

onBeforeUnmount(() => {
  if (objectUrl) URL.revokeObjectURL(objectUrl)
})
```

### reka-ui Tabs Import Pattern

```typescript
// Confirmed import path for reka-ui 2.x
import {
  TabsRoot,
  TabsList,
  TabsTrigger,
  TabsContent,
} from 'reka-ui'
```

### AdminApiProxyController — Detecting Multipart vs JSON POST

```php
// In AdminApiProxyController::handlePost()
private function handlePost(Request $request, string $endpoint): array
{
    // Cover image endpoints: POST /api/groups/:id/cover-image
    // The file key is 'image' per ApiService::upload() signature
    if ($request->hasFile('image')) {
        return $this->api->upload($endpoint, 'image', $request->file('image'), $request);
    }
    // All other POSTs are JSON
    return $this->api->post($endpoint, $request->json()->all() ?? [], $request);
}
```

### GroupActions.swift — Confirmed API Request Bodies

From direct inspection of `/iphone/MakeReady/State/Actions/GroupActions.swift`:

**POST /api/groups** (create):
```json
{
  "name": "string (required)",
  "isPrivate": false,
  "allowInvites": true,
  "memberDirectory": true,
  "description": "optional string",
  "coverImageUrl": "optional string",
  "welcomeMessage": "optional string",
  "ageRange": { "min": 0, "max": 100 },
  "maxMembers": 100
}
```
Response: `{ success: true, group: { id, name, ... } }`

**PATCH /api/groups/:id** (update):
Same fields as create, all optional. Same response shape.

**DELETE /api/groups/:id**:
No request body. Response: `{ success: true }`

**POST /api/groups/:id/cover-image**:
Multipart form data with `image` file key. Response: `{ success: true, coverImageUrl: "https://..." }`

**GET /api/groups** (list):
No request body. Response: `{ success: true, groups: [...] }`

**GET /api/groups/:id** (single):
No request body. Response: `{ success: true, group: { ... } }`

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate Pinia instance per island | Single AdminIsland with shared Pinia instance | Phase 5 established this | All groups stores share state with future programs/analytics stores — no re-fetch when switching sections |
| `window.confirm()` for delete | reka-ui Dialog component | Phase 6 establishes this | Styleable, focusable, consistent with dark theme |
| Full page reload on nav | Vue Router client-side navigation | Phase 5 established this | Group list → detail is instant, no Blade round-trip |
| base64 image upload | `FormData` multipart | Phase 6 establishes this | Handles real-world 3–5MB cover photos reliably |

---

## Open Questions

1. **`memberCount` field in GET /api/groups response**
   - What we know: GroupActions.swift loads groups via `GET /api/groups` and accesses individual group fields; the Swift `UserGroup` type is not in the audited files
   - What's unclear: Whether `memberCount` is returned in the list response or must be derived from a separate `GET /api/groups/:id/members` call
   - Recommendation: For GRP-01 (list with member count), display `—` if `memberCount` is null. Do not make an extra API call per group on list load. If `memberCount` is not in the list response, note it as a known display limitation.

2. **`ageRange` field nulling**
   - What we know: PATCH accepts `ageRange: { min?, max? }`
   - What's unclear: How to clear `ageRange` when a leader removes the age restriction — send `null` or omit the field?
   - Recommendation: Omit the field in the PATCH payload if the user clears the age range inputs. The Settings form simply won't include `ageRange` if both inputs are empty.

3. **Cover image upload file key**
   - What we know: Swift's `api.uploadImage(endpoint:, image:)` uploads to `/api/groups/:id/cover-image` using multipart
   - What's unclear: The exact form field key the API expects (the Swift code uses a generic `uploadImage` helper, not the raw `FormData` key)
   - Recommendation: Use `'image'` as the FormData key — this matches `ApiService::upload($endpoint, 'image', ...)` which hardcodes the field key. If the API rejects it, try `'file'` or `'photo'`.
   - Confidence: MEDIUM — the key is confirmed in `ApiService.php` but not verified against a live API response.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | PHPUnit (Laravel feature tests) |
| Config file | `phpunit.xml` |
| Quick run command | `php artisan test tests/Feature/AdminTest.php` |
| Full suite command | `php artisan test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GRP-01 | Groups list renders in AdminIsland for authenticated leader | smoke | `php artisan test tests/Feature/GroupsAdminTest.php --filter test_groups_list_renders` | ❌ Wave 0 |
| GRP-02 | POST /admin/api/groups proxied to external API with JSON body | integration | `php artisan test tests/Feature/GroupsAdminTest.php --filter test_create_group_proxy` | ❌ Wave 0 |
| GRP-03 | PATCH /admin/api/groups/:id proxied with partial fields | integration | `php artisan test tests/Feature/GroupsAdminTest.php --filter test_update_group_proxy` | ❌ Wave 0 |
| GRP-04 | Settings PATCH includes all settings fields (isPrivate, allowInvites, etc.) | integration | `php artisan test tests/Feature/GroupsAdminTest.php --filter test_update_group_settings_proxy` | ❌ Wave 0 |
| GRP-05 | POST /admin/api/groups/:id/cover-image forwards multipart file | integration | `php artisan test tests/Feature/GroupsAdminTest.php --filter test_cover_image_upload_proxy` | ❌ Wave 0 |
| GRP-06 | DELETE /admin/api/groups/:id proxied and returns success | integration | `php artisan test tests/Feature/GroupsAdminTest.php --filter test_delete_group_proxy` | ❌ Wave 0 |
| GRP-07 | Group detail page renders AdminIsland with correct route params | smoke | `php artisan test tests/Feature/GroupsAdminTest.php --filter test_group_detail_renders` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `php artisan test tests/Feature/GroupsAdminTest.php`
- **Per wave merge:** `php artisan test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/Feature/GroupsAdminTest.php` — covers GRP-01 through GRP-07
  - Follows `AdminTest.php` pattern: `Http::fake()` to mock external API, test Laravel proxy routing and response forwarding
  - Test for GRP-05 uses `UploadedFile::fake()->image('cover.jpg', 800, 600)->size(2000)` (2MB) to test multipart handling
  - All tests use `fakeSession()` helper like `AdminTest.php` to authenticate the leader

*(No framework install gaps — PHPUnit is installed and running.)*

---

## Sources

### Primary (HIGH confidence)

- `/iphone/MakeReady/State/Actions/GroupActions.swift` — authoritative API endpoints: GET /api/groups, POST /api/groups, PATCH /api/groups/:id, DELETE /api/groups/:id, POST /api/groups/:id/cover-image; all request body shapes and response shapes confirmed
- `/client/app/Services/ApiService.php` — `delete()`, `upload()`, `post()`, `patch()` methods confirmed present with correct signatures
- `/client/resources/js/islands/admin-island/admin-island.vue` — CSRF configuration pattern confirmed: reads `meta[name="csrf-token"]` in `onMounted`
- `/client/resources/js/islands/admin-island/router.ts` — Vue Router history mode, `/admin/groups` and `/admin/groups/:id` routes pre-registered
- `/client/resources/js/islands/admin-island/sections/groups-section.vue` — current stub, confirms component exists and uses `useRoute()`
- `/client/routes/web.php` — admin route group structure confirmed; admin catch-all at `/{any?}` with `->where('any', '.*')`; **no API proxy route exists yet**
- `/client/resources/js/stores/modal.store.ts` — Pinia composition API style confirmed (`defineStore` + `ref`/`computed` pattern)
- `/client/resources/css/layouts/admin-layout.scss` — `.AdminSection__header`, `.AdminSection__title`, `.AdminSection__body` confirmed; layout expects sections to use these BEM roots
- `/client/resources/css/app.scss` — SCSS `@use` registration pattern confirmed; admin components go under `// Admin components` section

### Secondary (MEDIUM confidence)

- reka-ui 2.9.2 installed — Tabs and Dialog confirmed present from package.json version; import paths from `'reka-ui'`
- `.planning/research/ARCHITECTURE.md` — domain/UI store separation pattern, image upload flow diagram
- `.planning/research/SUMMARY.md` — confirmed no new dependencies required for this phase
- `.planning/research/FEATURES.md` — API surface table confirms all group endpoints

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| API endpoints | HIGH | All five group endpoints confirmed directly from GroupActions.swift with request/response shapes |
| Proxy controller | HIGH | ApiService has all required methods; pattern documented in ARCHITECTURE.md |
| Pinia store pattern | HIGH | Follows established modal.store.ts composition style; domain/UI separation already proven |
| reka-ui Tabs/Dialog | MEDIUM | Package version confirmed installed (2.9.2); import paths are standard reka-ui convention but not tested against this version |
| Cover image file key | MEDIUM | 'image' key is what ApiService.php hardcodes; not verified against live API |
| memberCount availability | LOW | Not confirmed from Swift types; may or may not be in list response |

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (API is stable; stack is stable)
