<script setup lang="ts">
// GroupMembersPage — twin of iPhone Pages/Manage/Group/Member/
// GroupMembersPage.swift, the group-home modal's TRAILING SlideStack pane
// (person.2 toolbar icon).
//
// CORRECTED composition (spec 2026-07-05): PageTitle + SearchField +
// CardMember + purple "Respond" ActionButton — NOT MemberListItem; a FLAT
// name-sorted list (no AlphabetScrubber / sections index). Structure:
//   header "Members" (chevron.left back)
//   ZStack: ScrollView (60px top pad under the floating search; content
//   masked by a 52px top fade) ← SearchField overlaid pad-h16 pad-top8
//   Requests section (only when pending): "REQUESTS" header + CardMember rows
//   with a purple "Respond" button; then "MEMBERS" header (only when requests
//   exist) + plain CardMember rows ("Joined <date>" metadata, no trailing).
import CardMember from '../card-member/card-member.vue'
import type { CardMemberMetaItem } from '../card-member/card-member.vue'
import PageTitle from '../page-title/page-title.vue'
import SearchField from '../search-field/search-field.vue'

export interface GroupMemberRow {
  id: string
  firstName: string
  lastName: string
  avatarUrl?: string
  /** Pre-formatted "MMM d, yyyy" — "Joined" (members) / "Requested" (requests). */
  dateLabel: string
}

interface Props {
  members?: GroupMemberRow[]
  requests?: GroupMemberRow[]
  searchText?: string
  loading?: boolean
  errorMessage?: string
  interactive?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  members: () => [],
  requests: () => [],
  searchText: '',
  loading: false,
  errorMessage: '',
  interactive: false,
})

const emit = defineEmits<{
  back: []
  'update:searchText': [value: string]
  memberTap: [id: string]
  requestTap: [id: string]
  respond: [id: string]
  retry: []
}>()

const BACK_CHEVRON =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 4l-7 8 7 8"/></svg>'
// SF "person.2" — empty-state glyph (Typography.s48 white@0.3).
const PERSON_2 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7.5" r="3.3"/><path d="M3 19.5c0-3.3 2.7-5.6 6-5.6s6 2.3 6 5.6"/><path d="M15.2 4.6a3.3 3.3 0 0 1 0 6"/><path d="M16.6 14.2c2.5.5 4.4 2.6 4.4 5.3"/></svg>'
const WARN_TRIANGLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3.5 1.9 20.5h20.2z"/><path d="M12 9.5v5"/><circle cx="12" cy="17.4" r="0.4" fill="currentColor"/></svg>'

function memberMeta(row: GroupMemberRow, label: string): CardMemberMetaItem[] {
  return [{ label, value: row.dateLabel }]
}

// iOS: filteredMembers filters name.contains(search) — the twin filters its
// own rows so capture variants can seed searchText declaratively.
function matches(row: GroupMemberRow): boolean {
  if (!props.searchText) return true
  return `${row.firstName} ${row.lastName}`.toLowerCase().includes(props.searchText.toLowerCase())
}

const isEmpty = (): boolean => !props.members.length && !props.requests.length
</script>

<template>
  <div class="GroupMembersPage">
    <PageTitle
      class="GroupMembersPage__title"
      title="Members"
      :left-icon="BACK_CHEVRON"
      @left="emit('back')"
    />

    <!-- Loading (only when nothing cached) -->
    <div v-if="loading" class="GroupMembersPage__state">
      <span class="GroupMembersPage__stateSpinner" aria-label="Loading" />
    </div>

    <!-- Error (only when both lists empty) -->
    <div v-else-if="errorMessage" class="GroupMembersPage__state GroupMembersPage__state--error">
      <span class="GroupMembersPage__errorGlyph" aria-hidden="true" v-html="WARN_TRIANGLE" />
      <p class="GroupMembersPage__errorMessage">{{ errorMessage }}</p>
      <button type="button" class="GroupMembersPage__retry" @click="emit('retry')">Try Again</button>
    </div>

    <div v-else class="GroupMembersPage__body">
      <!-- Scroll content (60px pad under the floating search; 52px top fade) -->
      <div class="GroupMembersPage__scroll" :class="{ 'GroupMembersPage__scroll--masked': !isEmpty() }">
        <!-- Empty state -->
        <div v-if="isEmpty()" class="GroupMembersPage__empty">
          <span class="GroupMembersPage__emptyGlyph" aria-hidden="true" v-html="PERSON_2" />
          <p class="GroupMembersPage__emptyTitle">No members</p>
        </div>

        <template v-else>
          <!-- Requests (only when pending) -->
          <div v-if="requests.length" class="GroupMembersPage__section GroupMembersPage__section--requests">
            <span class="GroupMembersPage__sectionHeader">Requests</span>
            <div class="GroupMembersPage__cards">
              <CardMember
                v-for="r in requests"
                :key="r.id"
                :first-name="r.firstName"
                :last-name="r.lastName"
                :avatar-url="r.avatarUrl || undefined"
                :metadata="memberMeta(r, 'Requested')"
                show-invite
                invite-label="Respond"
                @click="emit('requestTap', r.id)"
                @invite="emit('respond', r.id)"
              />
            </div>
          </div>

          <!-- Members (header only when requests exist — iOS :328) -->
          <div
            v-if="members.filter(matches).length"
            class="GroupMembersPage__section"
            :class="{ 'GroupMembersPage__section--afterRequests': requests.length }"
          >
            <span v-if="requests.length" class="GroupMembersPage__sectionHeader">Members</span>
            <div class="GroupMembersPage__cards">
              <CardMember
                v-for="m in members.filter(matches)"
                :key="m.id"
                :first-name="m.firstName"
                :last-name="m.lastName"
                :avatar-url="m.avatarUrl || undefined"
                :metadata="memberMeta(m, 'Joined')"
                @click="emit('memberTap', m.id)"
              />
            </div>
          </div>
          <div v-else-if="searchText" class="GroupMembersPage__noResults">
            No results for &ldquo;{{ searchText }}&rdquo;
          </div>
        </template>

        <div class="GroupMembersPage__bottom-spacer" />
      </div>

      <!-- Floating search (iOS: overlaid, dimmed + inert when no members) -->
      <div
        class="GroupMembersPage__search"
        :class="{ 'GroupMembersPage__search--disabled': !members.length }"
      >
        <SearchField
          :interactive="interactive && members.length > 0"
          :search-text="searchText"
          :is-active="!!searchText"
          placeholder="Search members"
          @update:search-text="emit('update:searchText', $event)"
        />
      </div>
    </div>
  </div>
</template>
