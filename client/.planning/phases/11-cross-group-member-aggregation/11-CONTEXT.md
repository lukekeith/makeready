# Phase 11: Cross-Group Member Aggregation - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Build a new `all-members.domain` Pinia store that fans out to all groups in parallel, deduplicates members by `userId`, and exposes a reactive flat array of unified member objects. Also build a shell `member-activity.domain` store for activity history data (populated in Phase 14). No UI components — this is purely the data layer that Phase 12 (table/filters) consumes.

</domain>

<decisions>
## Implementation Decisions

### Member Row Shape (UnifiedMember)
- Each deduplicated member carries: `userId`, `name`, `avatarUrl`, `groups` (array of `{ groupId, groupName, role, joinedAt }`), `lastActive` (derived from most recent `joinedAt` across groups)
- `groups` array enables Phase 12 to render group chips per row and Phase 13 to show multi-group membership
- `userId` is the deduplication key (same person across groups has same `userId`)
- The existing `GroupMember` interface has `id` (membership ID), `userId`, `groupId`, `role`, `name`, `avatarUrl`, `joinedAt` — all fields needed are available

### Loading Behavior
- Load all groups on section mount (trigger from `members-section.vue` `onMounted`)
- Progressive: show members as each group's response arrives (reactive array updates per-group completion)
- `Promise.allSettled` — failed groups don't block others
- `isLoading` true until all groups settle, but members appear progressively
- Failed groups: store their names in a `failedGroups` ref, Phase 12 renders a warning banner

### Store Architecture
- **New store:** `all-members.domain.ts` — separate from existing `members.domain.ts`
- Composes with existing `useGroupsDomain` (reads `groups` list to know what to fan out)
- Composes with existing `useMembersDomain` (calls `loadMembers(groupId)` per group, reads `membersByGroup`)
- The deduplication logic (`allMembers` computed) lives in this new store
- Does NOT duplicate API calls — reuses the existing per-group cache in `members.domain`
- `member-activity.domain.ts` — shell store with empty refs for lesson history, enrollment progress, activity log (populated by Phase 14)

### Claude's Discretion
- Exact computed property implementation for deduplication
- Whether `lastActive` is computed or stored
- Error message wording for failed groups
- Whether `member-activity.domain` is created now (empty shell) or deferred entirely to Phase 14

</decisions>

<specifics>
## Specific Ideas

- The iPhone app does the same fan-out pattern — parallel load per group, dedup by userId. Match that.
- Research noted: `Promise.allSettled` is critical (not `Promise.all`) because one failed group shouldn't empty the entire list.
- Research noted: existing `loadedGroupIds` Set in `members.domain` enables caching — subsequent visits skip re-fetch.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `members.domain.ts`: `membersByGroup` (Record<string, GroupMember[]>), `loadMembers(groupId, force)`, `loadedGroupIds` cache, `loadMemberProfile(memberId)`
- `groups.domain.ts`: `groups` (Group[]), `loadGroups()` — provides the list of groupIds to fan out
- `GroupMember` interface: `id`, `userId`, `groupId`, `role`, `name`, `avatarUrl`, `joinedAt`
- `MemberProfile` interface: `id`, `firstName`, `lastName`, `phoneNumber`, `email`, `profilePicture`, `groups[]`

### Established Patterns
- Pinia Composition API: `defineStore('name', () => { const x = ref(); return { x } })`
- Domain stores own API calls, expose raw data
- UI stores compute derived/formatted data for components
- Cross-store composition: use `const otherStore = useOtherStore()` inside defineStore

### Integration Points
- `members-section.vue` `onMounted` → call `allMembersStore.loadAll()`
- `allMembersStore.allMembers` → consumed by Phase 12's `members-list.ui` store
- `groups.domain` already loaded by dashboard — may already have `groups` populated when navigating to /admin/members

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-cross-group-member-aggregation*
*Context gathered: 2026-03-21*
