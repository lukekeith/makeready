---
phase: 09-members-enrollments-posts-analytics-profile
plan: "04"
subsystem: admin-posts-tab
tags: [posts, pinia, vue, admin, pagination, type-badges, create-form]
dependency_graph:
  requires: [09-03-enrollment-detail-schedule-crud]
  provides: [posts-tab-panel, posts-domain-store, posts-tab-ui-store]
  affects: [groups-section.vue, posts.domain.ts, posts-tab.ui.ts]
tech_stack:
  added: []
  patterns: [cursor-pagination, type-conditional-form, type-badges, local-state-prepend]
key_files:
  created:
    - resources/js/islands/admin-island/stores/domain/posts.domain.ts
    - resources/js/islands/admin-island/stores/ui/posts-tab.ui.ts
    - resources/css/components/admin/admin-posts-tab.scss
  modified:
    - resources/js/islands/admin-island/sections/groups-section.vue
    - resources/css/app.scss
decisions:
  - "createPost prepends new post to postsByGroup[groupId] directly — API returns the full post object so local state update is sufficient without reload"
  - "loadPosts replaces list on first load (no cursor), appends on subsequent calls (with cursor) — matches cursor pagination contract"
  - "Poll options stored as ref<string[]> in UI store, not as object array — simpler for v-model binding in form, mapped to string[] in payload"
  - "PostType imported as type-only in groups-section.vue for the v-for cast — avoids runtime import overhead"
metrics:
  duration: "~5 min"
  completed_date: "2026-03-20"
  tasks_completed: 2
  files_changed: 5
---

# Phase 09 Plan 04: Posts Tab Panel Summary

Posts tab panel with paginated post list, color-coded type badges, type-aware create form (announcement, poll, event, video), and cursor-based Load More pagination built into the group detail admin view.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Posts domain store, UI store, and SCSS | 98fa294 | posts.domain.ts, posts-tab.ui.ts, admin-posts-tab.scss, app.scss |
| 2 | Wire Posts tab panel into groups-section.vue | 102b7ce | groups-section.vue |

## What Was Built

**posts.domain.ts** — Pinia composition store (ID: `posts-domain`). Exports `PostType`, `PollOption`, `GroupPost`, `CreatePostPayload` types. State: `postsByGroup` (keyed by groupId), `cursorByGroup`, `isLoading`, `error`. `loadPosts(groupId, cursor?)` GET `/admin/api/groups/:id/posts?limit=20` — replaces list on first load, appends on cursor load; stores `nextCursor` in `cursorByGroup`. `createPost(groupId, payload)` POST `/admin/api/groups/:id/posts` — prepends returned post to local list.

**posts-tab.ui.ts** — Pinia composition store (ID: `posts-tab-ui`). Separate form refs per field (`formTitle`, `formContent`, `formVideoUrl`, `formEventDate`, `formEventLocation`, `pollOptions`). Computeds: `groupId`, `posts`, `hasMore`, `isLoading`. `openCreate()` resets all form state; `buildPayload()` constructs type-correct `CreatePostPayload`; `submitCreate()` calls domain and closes form on success; `addPollOption()`/`removePollOption(index)` manage poll options (min 2).

**admin-posts-tab.scss** — BEM classes: PostsTab, PostsTab__list/card/card-header/author-avatar/author-name/date, PostsTab__type-badge with --announcement/#6c47ff, --poll/#0ea5e9, --event/#f59e0b, --video/#ef4444, --welcome/rgba white variants, PostsTab__content/poll-options/poll-option/event-meta/load-more, PostsTab__create-form/type-selector/type-btn/type-btn--active, PostsTab__form-row/label/input/textarea/poll-row/poll-remove.

**groups-section.vue** — `X` icon added to lucide imports. `usePostsTabUI` and `PostType` imported. `postsUI.loadData()` called in onMounted and route watcher alongside existing membersUI/enrollmentsUI calls. Posts tab `<TabsContent>` stub replaced with full panel: create button, type-conditional create form (title, content/question, poll options with add/remove, event date+location, video URL), post list with cards showing author avatar, name, type badge, date, title, content preview, poll options with vote counts, event meta, video link, and Load More button.

## Deviations from Plan

None — plan executed exactly as written.

## Success Criteria Verification

- [x] Posts tab replaces stub with paginated post list
- [x] Each post shows type badge (color-coded), author, content preview, date
- [x] Poll posts display options with vote counts
- [x] Event posts show date/time and location
- [x] Video posts show clickable URL
- [x] Create form switches fields based on selected type (announcement, poll, event, video)
- [x] Create submission handled entirely in UI store via submitCreate()
- [x] Poll form allows adding/removing options (min 2)
- [x] Load More button appears when nextCursor is non-null
- [x] npm run build passes
- [x] Post proxy tests pass (2 assertions)
- [x] Full test suite passes (228 passed, 1 incomplete pre-existing)

## Self-Check: PASSED

Files verified:
- resources/js/islands/admin-island/stores/domain/posts.domain.ts: FOUND
- resources/js/islands/admin-island/stores/ui/posts-tab.ui.ts: FOUND
- resources/css/components/admin/admin-posts-tab.scss: FOUND
- resources/js/islands/admin-island/sections/groups-section.vue: FOUND (modified)
- resources/css/app.scss: FOUND (modified)

Commits verified:
- 98fa294: feat(09-04): add posts domain store, UI store, and SCSS — FOUND
- 102b7ce: feat(09-04): wire Posts tab panel into groups-section.vue — FOUND
