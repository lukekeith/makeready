<script setup lang="ts">
// GroupHomeLeader — capture-only web twin of the iPhone LEADER screen
// `Pages/Manage/Group/GroupHomePage.swift` (its default, empty-posts state).
//
// This is NOT the production member group-home page (that lives untouched at
// resources/views/pages/group-home.blade.php). It exists only so the Compare
// tool's `group-home` comparison pairs the iPhone leader screen against a
// matching web leader screen instead of the member page.
//
// It REUSES existing design-system twins for every composed piece — the toolbar
// is PageTitle, the Invite/Enroll buttons are BoxButton, the Video/Message/
// Meeting chips are GroupActionButton — and only adds the page chrome (title
// section, divider, empty-posts state) that has no twin of its own. The SF
// Symbols are transcribed to inline SVG (drawn currentColor) reusing the exact
// markup the PageTitle / GroupActionButton adapters already ship.
import { computed } from 'vue'
import PageTitle from '../page-title/page-title.vue'
import BoxButton from '../box-button/box-button.vue'
import GroupActionButton from '../group-action-button/group-action-button.vue'
import CardLesson from '../card-lesson/card-lesson.vue'
import type { CardLessonActivity } from '../card-lesson/card-lesson.vue'
import GroupPostCard from '../group-post-card/group-post-card.vue'
import SkeletonPostCard from '../skeleton-post-card/skeleton-post-card.vue'

// Post item = the GroupPostCard prop bag (see group-post-card.vue).
export interface GroupHomePost {
  id: string
  type: 'announcement' | 'welcome' | 'event'
  authorName: string
  initials?: string
  avatarUrl?: string
  timeValue: string
  timeUnit: string
  text: string
  media?: 'photo' | null
  viewCount?: number
  shareCount?: number
  eventTitle?: string
  eventDateTime?: string
  eventDay?: string
  eventMonth?: string
  attendeeCount?: number
}

export interface GroupHomeNextLesson {
  mode?: string
  day?: number
  title?: string
  date?: string
  description?: string
  estimatedMinutes?: number
  activities?: CardLessonActivity[]
}

interface Props {
  groupName?: string
  isPrivate?: boolean
  memberCount?: number
  // ── Additive (2026-07-04, full GroupHomePage parity) — every prop defaults
  // to the originally-captured empty-posts rendering. ──
  /** 240px cover header (AsyncImage variant); omitted by the capture adapter. */
  coverUrl?: string
  /** Red join-request dot on the person.2 toolbar icon. */
  showRequestBadge?: boolean
  /** "NEXT LESSON" section (iOS renders it only when a lesson is upcoming). */
  nextLesson?: GroupHomeNextLesson | null
  /** Posts wall; empty + !postsLoading = the original "No posts yet" state. */
  posts?: GroupHomePost[]
  /** First-load state: 3× SkeletonPostCard. */
  postsLoading?: boolean
  /** Pending-enrollment placeholder card rendered before the posts. */
  pendingEnrollment?: { programName?: string | null; programImageUrl?: string | null } | null
  /** Pagination spinner under the list. */
  hasMorePosts?: boolean
  /** CAPTURE-ONLY status-bar inset (matches iPhone DeviceChrome); production never passes it. */
  statusBar?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  groupName: 'Group',
  isPrivate: false,
  memberCount: 0,
  coverUrl: '',
  showRequestBadge: false,
  nextLesson: null,
  posts: () => [],
  postsLoading: false,
  pendingEnrollment: null,
  hasMorePosts: false,
  statusBar: false,
})

// Production wiring (compare harness binds none of these).
const emit = defineEmits<{
  dismiss: []
  invite: []
  members: []
  calendar: []
  enrollments: []
  settings: []
  enroll: []
  chip: [type: 'video' | 'message' | 'meeting']
  nextLessonTap: []
  /** Fired when the scroller nears the bottom while hasMorePosts (iOS load-more onAppear). */
  loadMore: []
}>()

function onScroll(e: Event): void {
  if (!props.hasMorePosts) return
  const el = e.target as HTMLElement
  if (el.scrollTop + el.clientHeight >= el.scrollHeight - 200) emit('loadMore')
}

// Toolbar right-icon order: paperplane / person.2 / calendar / book / gearshape.
const RIGHT_ICON_EMITS = ['invite', 'members', 'calendar', 'enrollments', 'settings'] as const
function onRightIcon(i: number): void {
  emit(RIGHT_ICON_EMITS[i] as (typeof RIGHT_ICON_EMITS)[number])
}

// ── Toolbar SF Symbols (outline) — copied verbatim from PageTitle.mjs ──
const XMARK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 5l14 14M19 5L5 19"/></svg>'
const PAPERPLANE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M21.5 2.5L2.6 9.7a0.5 0.5 0 0 0 0 0.95l7.3 2.55 2.55 7.3a0.5 0.5 0 0 0 0.95 0z"/><path d="M21.5 2.5L9.9 13.2"/></svg>'
const PERSON_2 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7.5" r="3.3"/><path d="M3 19.5c0-3.3 2.7-5.6 6-5.6s6 2.3 6 5.6"/><path d="M15.2 4.6a3.3 3.3 0 0 1 0 6"/><path d="M16.6 14.2c2.5.5 4.4 2.6 4.4 5.3"/></svg>'
const CALENDAR =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4.5" width="18" height="16.5" rx="2.6"/><path d="M3 9.2h18"/><g fill="currentColor" stroke="none"><circle cx="7.5" cy="13" r="0.95"/><circle cx="12" cy="13" r="0.95"/><circle cx="16.5" cy="13" r="0.95"/><circle cx="7.5" cy="17" r="0.95"/><circle cx="12" cy="17" r="0.95"/><circle cx="16.5" cy="17" r="0.95"/></g></svg>'
const GEARSHAPE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3.2"/><path d="M19.4 13a1.7 1.7 0 0 0 .34 1.87l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.7 1.7 0 0 0-1.87-.34 1.7 1.7 0 0 0-1.03 1.56V19a2 2 0 1 1-4 0v-.09A1.7 1.7 0 0 0 8.8 17.4a1.7 1.7 0 0 0-1.87.34l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.7 1.7 0 0 0 4.6 13a1.7 1.7 0 0 0-1.56-1.03H3a2 2 0 1 1 0-4h.09A1.7 1.7 0 0 0 4.6 6.93a1.7 1.7 0 0 0-.34-1.87l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.7 1.7 0 0 0 1.87.34H9a1.7 1.7 0 0 0 1.03-1.56V1a2 2 0 1 1 4 0v.09a1.7 1.7 0 0 0 1.03 1.56 1.7 1.7 0 0 0 1.87-.34l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.7 1.7 0 0 0 19.4 7v.05a1.7 1.7 0 0 0 1.56 1.03H21a2 2 0 1 1 0 4h-.09A1.7 1.7 0 0 0 19.4 13z"/></svg>'
// SF "book" — open book outline (toolbar enrollments).
const BOOK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 6.5C10.5 5.3 8.4 4.7 5.8 4.7c-.9 0-1.7.07-2.3.18v13c.6-.1 1.4-.18 2.3-.18 2.6 0 4.7.6 6.2 1.8 1.5-1.2 3.6-1.8 6.2-1.8.9 0 1.7.07 2.3.18v-13c-.6-.1-1.4-.18-2.3-.18-2.6 0-4.7.6-6.2 1.8z"/><path d="M12 6.5V19"/></svg>'

const RIGHT_ICONS = computed(() => [
  { icon: PAPERPLANE },
  { icon: PERSON_2, showBadge: props.showRequestBadge },
  { icon: CALENDAR },
  { icon: BOOK },
  { icon: GEARSHAPE },
])

// SF "checkmark.circle" — Enroll button (primary).
const CHECKMARK_CIRCLE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M8 12.5l2.5 2.5L16 9"/></svg>'

// ── Chip SF Symbols (filled) — copied verbatim from GroupActionButton.mjs ──
const VIDEO_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4 6.5h9A2.5 2.5 0 0 1 15.5 9v6A2.5 2.5 0 0 1 13 17.5H4A2.5 2.5 0 0 1 1.5 15V9A2.5 2.5 0 0 1 4 6.5zM17 9.6l4.2-2.6c.5-.3 1.3-.06 1.3.6v8.8c0 .66-.8.9-1.3.6L17 14.4z"/></svg>'
const MESSAGE_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 3C6.5 3 2 6.7 2 11.2c0 2.6 1.5 4.9 3.8 6.4-.2 1-.8 2.3-1.6 3.2-.22.26.02.66.36.56 1.9-.5 3.4-1.2 4.5-1.9.9.2 1.9.3 2.9.3 5.5 0 10-3.7 10-8.6S17.5 3 12 3z"/></svg>'
const PERSON_2_FILL =
  '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="8.8" cy="7.4" r="3.2"/><path d="M8.8 11.6c-3.1 0-5.6 1.9-5.6 4.4 0 .9.7 1.5 1.6 1.5h8c.9 0 1.6-.6 1.6-1.5 0-2.5-2.5-4.4-5.6-4.4z"/><circle cx="16.6" cy="8" r="2.7"/><path d="M16.6 11.8c-.9 0-1.6.16-2.3.45 1.2 1.05 1.95 2.5 1.95 4.1 0 .3-.05.6-.15.9h3.9c.85 0 1.5-.55 1.5-1.4 0-2.3-2.2-4.05-4.9-4.05z"/></svg>'

// SF "lock.fill" / "lock.open.fill" — privacy glyph in the info row.
const LOCK_FILL =
  '<svg viewBox="0 0 24 24" fill="none"><path d="M7.2 10.5V8a4.8 4.8 0 0 1 9.6 0v2.5" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><rect x="4.7" y="10" width="14.6" height="10.8" rx="2.4" fill="currentColor"/></svg>'
const LOCK_OPEN_FILL =
  '<svg viewBox="0 0 24 24" fill="none"><path d="M7.2 10.5V8a4.8 4.8 0 0 1 9.1-1.6" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><rect x="4.7" y="10" width="14.6" height="10.8" rx="2.4" fill="currentColor"/></svg>'

// SF "bubble.left.and.bubble.right" — empty-posts glyph.
const BUBBLES =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M2.5 8.5c0-2.2 2-4 4.5-4h5c2.5 0 4.5 1.8 4.5 4s-2 4-4.5 4H9l-3.2 2.4c-.3.2-.7 0-.7-.4V12.3c-1.6-.6-2.6-2-2.6-3.8z"/><path d="M17.4 9.2c2 .3 3.6 1.7 3.6 3.6 0 1.3-.8 2.5-2 3.1v2.3c0 .4-.4.6-.7.4L16 18.2h-2.2c-1.4 0-2.7-.6-3.4-1.6"/></svg>'
</script>

<template>
  <div class="GroupHomeLeader">
    <!-- Toolbar: PageTitle.iconTitleIcons — xmark + paperplane/person.2/calendar/book/gearshape -->
    <div v-if="statusBar" class="GroupHomeLeader__statusbar" aria-hidden="true">
      <span class="GroupHomeLeader__clock">9:41</span>
    </div>

    <PageTitle
      class="GroupHomeLeader__toolbar"
      factory="iconTitleIcons"
      :title="''"
      :left-icon="XMARK"
      :right-icons="RIGHT_ICONS"
      @left="emit('dismiss')"
      @select-right-icon="onRightIcon"
    />

    <div class="GroupHomeLeader__scroll" @scroll.passive="onScroll">
      <!-- Cover header (AsyncImage 240px scaledToFill + clear→canvas gradient,
           title overlaid bottom-leading pad 16). Capture adapter omits coverUrl
           so the original no-cover rendering is unchanged. -->
      <div v-if="coverUrl" class="GroupHomeLeader__cover">
        <img class="GroupHomeLeader__cover-img" :src="coverUrl" alt="" />
        <div class="GroupHomeLeader__cover-gradient" />
        <div class="GroupHomeLeader__title-section GroupHomeLeader__title-section--overlay">
          <h1 class="GroupHomeLeader__name">{{ groupName }}</h1>
          <div class="GroupHomeLeader__info">
            <span class="GroupHomeLeader__privacy">
              <span class="GroupHomeLeader__privacy-glyph" aria-hidden="true" v-html="isPrivate ? LOCK_FILL : LOCK_OPEN_FILL" />
              <span class="GroupHomeLeader__privacy-label">{{ isPrivate ? 'Private group' : 'Public group' }}</span>
            </span>
            <span class="GroupHomeLeader__count">
              <span class="GroupHomeLeader__count-value">{{ memberCount }}</span>
              <span class="GroupHomeLeader__count-label">members</span>
            </span>
          </div>
        </div>
      </div>

      <!-- Title section (no cover image) -->
      <div v-else class="GroupHomeLeader__title-section">
        <h1 class="GroupHomeLeader__name">{{ groupName }}</h1>
        <div class="GroupHomeLeader__info">
          <span class="GroupHomeLeader__privacy">
            <span class="GroupHomeLeader__privacy-glyph" aria-hidden="true" v-html="isPrivate ? LOCK_FILL : LOCK_OPEN_FILL" />
            <span class="GroupHomeLeader__privacy-label">{{ isPrivate ? 'Private group' : 'Public group' }}</span>
          </span>
          <span class="GroupHomeLeader__count">
            <span class="GroupHomeLeader__count-value">{{ memberCount }}</span>
            <span class="GroupHomeLeader__count-label">members</span>
          </span>
        </div>
      </div>

      <!-- Action buttons row: Invite (secondary) / Enroll (primary), 50% each -->
      <div class="GroupHomeLeader__actions">
        <BoxButton label="Invite" :icon="PAPERPLANE" icon-position="left" variant="secondary" size="md" full-width @click="emit('invite')" />
        <BoxButton label="Enroll" :icon="CHECKMARK_CIRCLE" icon-position="left" variant="primary" size="md" full-width @click="emit('enroll')" />
      </div>

      <!-- Horizontally scrolling action chips -->
      <div class="GroupHomeLeader__chips">
        <GroupActionButton label="Video" :icon="VIDEO_FILL" @click="emit('chip', 'video')" />
        <GroupActionButton label="Message" :icon="MESSAGE_FILL" @click="emit('chip', 'message')" />
        <GroupActionButton label="Meeting" :icon="PERSON_2_FILL" @click="emit('chip', 'meeting')" />
      </div>

      <!-- Divider above posts -->
      <div class="GroupHomeLeader__divider" />

      <!-- NEXT LESSON (iOS nextLessonSection — only when a lesson is upcoming) -->
      <div v-if="nextLesson" class="GroupHomeLeader__next-lesson">
        <span class="GroupHomeLeader__next-lesson-label">Next lesson</span>
        <CardLesson v-bind="nextLesson" @click="emit('nextLessonTap')" />
        <div class="GroupHomeLeader__divider GroupHomeLeader__next-lesson-divider" />
      </div>

      <!-- Posts wall: skeletons (first load) / list / empty -->
      <template v-if="postsLoading && !posts.length">
        <template v-for="n in 3" :key="`skeleton-${n}`">
          <SkeletonPostCard />
          <div v-if="n < 3" class="GroupHomeLeader__divider" />
        </template>
      </template>
      <template v-else-if="posts.length || pendingEnrollment">
        <template v-if="pendingEnrollment">
          <SkeletonPostCard
            :program-name="pendingEnrollment.programName ?? null"
            :program-image-url="pendingEnrollment.programImageUrl ?? null"
          />
          <div v-if="posts.length" class="GroupHomeLeader__divider" />
        </template>
        <template v-for="(post, i) in posts" :key="post.id">
          <GroupPostCard v-bind="post" />
          <div v-if="i < posts.length - 1" class="GroupHomeLeader__divider" />
        </template>
        <!-- Pagination spinner (iOS ProgressView, pad-v 20) — static spokes. -->
        <div v-if="hasMorePosts" class="GroupHomeLeader__load-more">
          <span class="GroupHomeLeader__load-more-spinner" aria-hidden="true">
            <svg viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.6" stroke-linecap="round">
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="1" transform="rotate(0 12 12)" />
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.85" transform="rotate(45 12 12)" />
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.7" transform="rotate(90 12 12)" />
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.6" transform="rotate(135 12 12)" />
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.5" transform="rotate(180 12 12)" />
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.4" transform="rotate(225 12 12)" />
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.3" transform="rotate(270 12 12)" />
              <line x1="12" y1="4.5" x2="12" y2="8" opacity="0.2" transform="rotate(315 12 12)" />
            </svg>
          </span>
        </div>
      </template>
      <!-- Empty posts state (the original captured default) -->
      <div v-else class="GroupHomeLeader__empty">
        <span class="GroupHomeLeader__empty-glyph" aria-hidden="true" v-html="BUBBLES" />
        <p class="GroupHomeLeader__empty-title">No posts yet</p>
        <p class="GroupHomeLeader__empty-subtitle">Be the first to share something with the group</p>
      </div>

      <!-- iOS bottom Spacer(40) -->
      <div class="GroupHomeLeader__bottom-spacer" />
    </div>
  </div>
</template>
