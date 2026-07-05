<script setup lang="ts">
// GroupsView — the "Groups" tab of the mobile leader app, a production rebuild of
// the iPhone MemberHomePage (Pages/Manage/Member/MemberHomePage.swift). One page
// with three sub-tabs driven by the shared PageHeader twin:
//   • Groups   — the org's groups the leader manages (CardGroup)
//   • Members  — every group's members, deduped, searchable (CardMember)
//   • Enrolled — every group's study enrollments (CardEnrolled)
// All data comes from the /admin/api proxy via the leader-groups store. Reuses the
// design-system card twins; only the page chrome (tab header + lists) lives here.
import { computed, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import PageHeader from '../../../components/card/page-header/page-header.vue'
import CardGroup from '../../../components/card/card-group/card-group.vue'
import CardMember from '../../../components/card/card-member/card-member.vue'
import CardEnrolled from '../../../components/card/card-enrolled/card-enrolled.vue'
import SearchField from '../../../components/card/search-field/search-field.vue'
import SkeletonCardGroup from '../../../components/card/skeleton-card-group/skeleton-card-group.vue'
import { useLeaderGroups } from '../stores/leader-groups.store'
import GroupHomeModal from '../components/group-home-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'

const store = useLeaderGroups()
const route = useRoute()
const router = useRouter()
const overlayManager = useOverlayManager()

// iOS MemberHomePage.presentGroupHome — card tap → .groupHome modal overlay.
function openGroupHome(groupId: string): void {
  overlayManager.present(ROUTES.groupHome, GroupHomeModal, { groupId })
}

// Each tab is its own route (/admin/groups/{list,members,enrolled}) so it's
// deep-linkable and survives a refresh. The active index is derived from the
// route's `groupsTab` meta; clicking a tab navigates.
const TAB_SLUGS = ['list', 'members', 'enrolled'] as const
const activeTab = computed(() => {
  const i = TAB_SLUGS.indexOf((route.meta.groupsTab as typeof TAB_SLUGS[number]) ?? 'list')
  return i < 0 ? 0 : i
})
function selectTab(index: number): void {
  const path = `/admin/groups/${TAB_SLUGS[index]}`
  if (route.path !== path) router.push(path)
}

// Load the active tab's data (immediate so a deep-linked refresh loads too; the
// store caches, so revisiting a tab is a no-op).
store.loadGroups()
watch(
  activeTab,
  (tab) => {
    if (tab === 1) store.loadMembers()
    else if (tab === 2) store.loadEnrolled()
  },
  { immediate: true },
)

// ── Search (shared across all three tabs; cleared on tab switch) ──
const search = ref('')
watch(activeTab, () => { search.value = '' })

const searchPlaceholder = computed(() =>
  activeTab.value === 1 ? 'Search members' : activeTab.value === 2 ? 'Search studies' : 'Search groups',
)

const filteredGroups = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return store.groups
  return store.groups.filter((g) => g.name.toLowerCase().includes(q))
})
const filteredMembers = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return store.members
  return store.members.filter((m) => m.name.toLowerCase().includes(q))
})
const filteredEnrollments = computed(() => {
  const q = search.value.trim().toLowerCase()
  if (!q) return store.enrollments
  return store.enrollments.filter(
    (e) => e.studyTitle.toLowerCase().includes(q) || e.groupName.toLowerCase().includes(q),
  )
})

function memberMeta(count: number) {
  return [{ number: count, label: count === 1 ? 'Member' : 'Members' }]
}

// Trailing PageHeader actions (iOS: paperplane → invite, plus → create group).
// The menus are a follow-up; the buttons are rendered for layout parity.
const PAPERPLANE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2.5L2.6 9.7a0.5 0.5 0 0 0 0 0.95l7.3 2.55 2.55 7.3a0.5 0.5 0 0 0 0.95 0z"/><path d="M21.5 2.5L9.9 13.2"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
</script>

<template>
  <div class="LeaderGroups">
    <div class="LeaderGroups__top">
      <div class="LeaderGroups__headerRow">
        <PageHeader
          class="LeaderGroups__header"
          :tabs="['Groups', 'Members', 'Enrolled']"
          :active-tab="activeTab"
          @select="selectTab"
        />
        <div class="LeaderGroups__actions">
          <button class="LeaderGroups__actionBtn" type="button" aria-label="Invite" v-html="PAPERPLANE"></button>
          <button class="LeaderGroups__actionBtn" type="button" aria-label="Create" v-html="PLUS"></button>
        </div>
      </div>
      <div class="LeaderGroups__searchWrap">
        <SearchField
          interactive
          :is-active="!!search"
          :search-text="search"
          :placeholder="searchPlaceholder"
          @update:search-text="search = $event"
        />
      </div>
    </div>

    <!-- ── Groups tab ── -->
    <div v-show="activeTab === 0" class="LeaderGroups__scroll">
      <div v-if="store.groupsLoading && !store.groups.length" class="LeaderGroups__list">
        <SkeletonCardGroup />
        <SkeletonCardGroup />
        <SkeletonCardGroup />
      </div>
      <div v-else-if="store.groupsError" class="LeaderGroups__state">{{ store.groupsError }}</div>
      <div v-else-if="!store.groups.length" class="LeaderGroups__empty">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
        <p class="LeaderGroups__emptyTitle">No Groups</p>
        <p class="LeaderGroups__emptySub">Create your first group to start connecting</p>
      </div>
      <div v-else-if="!filteredGroups.length" class="LeaderGroups__state">No results for “{{ search }}”</div>
      <div v-else class="LeaderGroups__list">
        <CardGroup
          v-for="g in filteredGroups"
          :key="g.id"
          :name="g.name"
          :member-count="g.memberCount"
          :metadata="memberMeta(g.memberCount)"
          :image-url="g.coverImageUrl || undefined"
          icon-fallback
          @click="openGroupHome(g.id)"
        />
      </div>
    </div>

    <!-- ── Members tab ── -->
    <div v-show="activeTab === 1" class="LeaderGroups__scroll">
      <div v-if="store.membersLoading && !store.members.length" class="LeaderGroups__state">Loading…</div>
      <div v-else-if="store.membersError" class="LeaderGroups__state">{{ store.membersError }}</div>
      <template v-else>
        <button
          v-if="store.requests.length && !search"
          class="LeaderGroups__requests"
          type="button"
        >
          <span class="LeaderGroups__requestsLabel">Member requests</span>
          <span class="LeaderGroups__requestsCount">{{ store.requests.length }}</span>
          <svg class="LeaderGroups__requestsChevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 6l6 6-6 6" /></svg>
        </button>

        <div v-if="filteredMembers.length" class="LeaderGroups__list">
          <CardMember
            v-for="m in filteredMembers"
            :key="m.userId"
            :first-name="m.firstName"
            :last-name="m.lastName"
            :avatar-url="m.avatarUrl || undefined"
            :metadata="[{ label: 'Joined', value: m.joinedLabel }]"
            :groups="m.groups"
            :max-groups="1"
          />
        </div>
        <div v-else-if="search" class="LeaderGroups__state">No results for “{{ search }}”</div>
        <div v-else class="LeaderGroups__empty">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
          </svg>
          <p class="LeaderGroups__emptyTitle">No members</p>
        </div>
      </template>
    </div>

    <!-- ── Enrolled tab ── -->
    <div v-show="activeTab === 2" class="LeaderGroups__scroll">
      <div v-if="store.enrolledLoading && !store.enrollments.length" class="LeaderGroups__state">Loading…</div>
      <div v-else-if="store.enrolledError" class="LeaderGroups__state">{{ store.enrolledError }}</div>
      <div v-else-if="!store.enrollments.length" class="LeaderGroups__empty">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <rect x="3" y="4.5" width="18" height="16.5" rx="2.5" /><path d="M3 9.5h18M8 2.5v4M16 2.5v4" />
        </svg>
        <p class="LeaderGroups__emptyTitle">No Enrollments</p>
        <p class="LeaderGroups__emptySub">Enroll a group in a study program to get started</p>
      </div>
      <div v-else-if="!filteredEnrollments.length" class="LeaderGroups__state">No results for “{{ search }}”</div>
      <div v-else class="LeaderGroups__list LeaderGroups__list--enrolled">
        <CardEnrolled
          v-for="e in filteredEnrollments"
          :key="e.id"
          :study-title="e.studyTitle"
          :group-name="e.groupName"
          :date-range="e.dateRange"
          :lessons-left="e.lessonsLeft"
          :studyImageURL="e.studyImageURL || undefined"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.LeaderGroups {
  display: flex;
  flex-direction: column;
}

/* Fixed top region (tab header + search): stays put while content scrolls
   underneath it. Frosted: dark canvas @ 50% over a 20px backdrop blur (matches
   the bottom nav). */
.LeaderGroups__top {
  position: sticky;
  top: 0;
  z-index: 5;
  background: var(--surface-nav);
  backdrop-filter: blur(var(--blur-lg));
  -webkit-backdrop-filter: blur(var(--blur-lg));
}

/* Position context for the absolute action buttons. */
.LeaderGroups__headerRow {
  position: relative;
  min-height: var(--header-height);
}

/* Search row beneath the tabs, shown on every tab. */
.LeaderGroups__searchWrap {
  padding: 0 16px 8px;
}

/* Trailing actions — two 32px white@10% circles, centered on the tab row. */
.LeaderGroups__actions {
  position: absolute;
  top: 19px;
  right: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.LeaderGroups__actionBtn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  border-radius: 50%;
  background: var(--color-white-10);
  color: #fff;
  cursor: pointer;
}

.LeaderGroups__actionBtn :deep(svg) {
  width: 16px;
  height: 16px;
  display: block;
}

.LeaderGroups__scroll {
  padding: 8px 16px 16px;
}

.LeaderGroups__list {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.LeaderGroups__list--enrolled {
  gap: 4px;
  padding-top: 8px;
}

/* Member requests row (iOS memberRequestsCard). */
.LeaderGroups__requests {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 12px;
  padding: 14px 16px;
  border: none;
  border-radius: 12px;
  background: var(--color-white-5, rgba(255, 255, 255, 0.08));
  color: #fff;
  cursor: pointer;
}

.LeaderGroups__requestsLabel {
  flex: 1 1 auto;
  text-align: left;
  font-size: 17px;
  font-weight: 600;
}

.LeaderGroups__requestsCount {
  font-size: 17px;
  font-weight: 600;
  color: var(--color-white-50);
}

.LeaderGroups__requestsChevron {
  width: 16px;
  height: 16px;
  color: var(--color-white-20);
}

.LeaderGroups__state {
  padding: 40px 16px;
  text-align: center;
  font-size: 15px;
  color: var(--color-white-50);
}

.LeaderGroups__empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  padding: 64px 24px;
  text-align: center;
}

.LeaderGroups__empty svg {
  width: 48px;
  height: 48px;
  color: var(--color-white-20);
}

.LeaderGroups__emptyTitle {
  margin: 0;
  font-size: 20px;
  font-weight: 700;
  color: #fff;
}

.LeaderGroups__emptySub {
  margin: 0;
  font-size: 15px;
  color: var(--color-white-50);
  max-width: 260px;
}
</style>
