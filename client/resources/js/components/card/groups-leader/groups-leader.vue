<script setup lang="ts">
// GroupsLeader — capture-only web leader twin of the iPhone "Groups" tab of
// MemberHomePage (Pages/Manage/Member/MemberHomePage.swift, rendered via the
// ViewRegistry `pages.groups` case with pendingSubTab 0). Capture-only, like
// home-dashboard / group-home-leader; the production member groups list
// (resources/views/pages/groups.blade.php) and the admin SPA stay untouched.
//
// Composed entirely from existing design-system twins — PageHeader (the
// Groups/Members/Enrolled tab row) and CardGroup (each group row) — plus the
// page chrome the iPhone screen adds around them: the device status bar, the
// PageHeader's trailing paperplane/plus action buttons, and the scrolling list.
import PageHeader from '../page-header/page-header.vue'
import CardGroup from '../card-group/card-group.vue'

interface Group {
  id: string
  name: string
  memberCount: number
}

interface Props {
  groups?: Group[]
}

const props = withDefaults(defineProps<Props>(), {
  groups: () => [],
})

// iOS metadata is a single `.number` DataItem — value + pluralized "Members".
function memberMeta(count: number) {
  return [{ number: count, label: count === 1 ? 'Member' : 'Members' }]
}

// Trailing action buttons (iOS PageHeader trailing ViewBuilder): paperplane
// (s14) opens the invite menu, plus (s16) opens the create menu — both in a
// 32pt white@10% circle. SF-symbol outlines transcribed to inline SVG.
const PAPERPLANE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2.5L2.6 9.7a0.5 0.5 0 0 0 0 0.95l7.3 2.55 2.55 7.3a0.5 0.5 0 0 0 0.95 0z"/><path d="M21.5 2.5L9.9 13.2"/></svg>'
const PLUS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"><path d="M12 5.5v13M5.5 12h13"/></svg>'
</script>

<template>
  <div class="GroupsLeader">
    <!-- iOS device status bar (62pt top safe-area inset). The pages.groups
         capture renders MemberHomePage, whose VStack starts below the safe
         area; reproducing the status bar keeps the PageHeader aligned. -->
    <div class="GroupsLeader__statusbar" aria-hidden="true">
      <span class="GroupsLeader__clock">9:41</span>
      <span class="GroupsLeader__indicators">
        <svg class="GroupsLeader__statusIcon" width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" />
          <rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" />
          <rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg class="GroupsLeader__statusIcon" width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg class="GroupsLeader__statusIcon GroupsLeader__battery" width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <!-- PageHeader (Groups/Members/Enrolled) + trailing paperplane/plus. The
         buttons are MemberHomePage page chrome (PageHeader's trailing slot),
         not part of the shared PageHeader twin, so they live here. -->
    <div class="GroupsLeader__headerRow">
      <PageHeader class="GroupsLeader__header" :tabs="['Groups', 'Members', 'Enrolled']" :active-tab="0" />
      <div class="GroupsLeader__actions">
        <span class="GroupsLeader__actionBtn" aria-hidden="true" v-html="PAPERPLANE"></span>
        <span class="GroupsLeader__actionBtn GroupsLeader__actionBtn--plus" aria-hidden="true" v-html="PLUS"></span>
      </div>
    </div>

    <!-- Groups list — iOS ScrollView { VStack(spacing: 4) of CardGroup,
         .padding(.horizontal, 16) } with .padding(.bottom, 100). -->
    <div class="GroupsLeader__scroll">
      <div class="GroupsLeader__list">
        <CardGroup
          v-for="group in props.groups"
          :key="group.id"
          :name="group.name"
          :member-count="group.memberCount"
          :metadata="memberMeta(group.memberCount)"
          icon-fallback
        />
      </div>
    </div>
  </div>
</template>
