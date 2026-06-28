<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import Avatar from '../../primitive/avatar/avatar.vue'

// GroupPostCard — a post in a group feed (iOS GroupPostCard parity). Header is an
// avatar + author name + two-tone relative timestamp; below is the post body and
// then type-specific content:
//   announcement / welcome → optional full-width media (rendered as the
//       iOS AsyncImage placeholder) + an action bar (views / reposts / bookmark /
//       share).
//   event → an event card (cover placeholder + date column + title / date-time /
//       attendee count). Events have no action bar.
//
// Fully data-driven via props. Media URLs are intentionally NOT loaded — the iOS
// reference renders the AsyncImage placeholder in isolated snapshots, so the twin
// renders a matching placeholder whenever `media` is set. The relative timestamp
// is pre-split into value / unit (two-tone) by the adapter.
//
// Fields (props):
//   type          'announcement' | 'welcome' | 'event'
//   authorName    string   — post author (bold)
//   initials      string   — avatar fallback initials (avatar always shows these
//                            in isolated capture, matching iOS)
//   avatarUrl     string?  — author avatar (omitted by the capture adapter)
//   timeValue     string   — relative-time number, e.g. "956" (white 70%)
//   timeUnit      string   — relative-time unit, e.g. "days ago" (white 50%)
//   text          string   — post body
//   media         'photo' | null — non-event media placeholder
//   viewCount     number?  — action-bar view count
//   shareCount    number?  — action-bar repost count
//   eventTitle    string?  — event card title
//   eventDateTime string?  — formatted "Tuesday October 28 - 7:00pm"
//   eventDay      string?  — big day number, e.g. "28"
//   eventMonth    string?  — month abbreviation, e.g. "OCT"
//   attendeeCount number?  — event attendee count
interface Props {
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
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  initials: '',
  avatarUrl: '',
  media: null,
  viewCount: 0,
  shareCount: 0,
  attendeeCount: 0,
})

const classes = computed(() => classnames('GroupPostCard', props.class))
const isEvent = computed(() => props.type === 'event')
</script>

<template>
  <div :class="classes">
    <!-- Author row -->
    <header class="GroupPostCard__header">
      <Avatar
        size="Md"
        :src="avatarUrl || undefined"
        :initials="initials"
        :alt="authorName"
        class="GroupPostCard__avatar"
      />
      <div class="GroupPostCard__byline">
        <span class="GroupPostCard__author">{{ authorName }}</span>
        <span class="GroupPostCard__time">
          <span class="GroupPostCard__timeValue">{{ timeValue }}</span>
          <span class="GroupPostCard__timeUnit">{{ timeUnit }}</span>
        </span>
      </div>
    </header>

    <!-- Body -->
    <p class="GroupPostCard__body">{{ text }}</p>

    <!-- Non-event media placeholder (matches iOS AsyncImage placeholder) -->
    <div
      v-if="!isEvent && media === 'photo'"
      class="GroupPostCard__media"
      aria-hidden="true"
    >
      <svg class="GroupPostCard__placeholderGlyph" viewBox="0 0 24 24" fill="currentColor">
        <path d="M19 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zm0 16H5l3.5-4.5 2.5 3.01L14.5 12 19 18z" />
        <circle cx="8.5" cy="8.5" r="1.6" />
      </svg>
    </div>

    <!-- Event card -->
    <div v-if="isEvent" class="GroupPostCard__event">
      <div class="GroupPostCard__eventCover" aria-hidden="true">
        <svg class="GroupPostCard__placeholderGlyph" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="4" width="18" height="18" rx="2" />
          <path d="M16 2v4M8 2v4M3 10h18" />
        </svg>
      </div>
      <div class="GroupPostCard__eventRow">
        <div class="GroupPostCard__eventDate">
          <span class="GroupPostCard__eventDay">{{ eventDay }}</span>
          <span class="GroupPostCard__eventMonth">{{ eventMonth }}</span>
        </div>
        <div class="GroupPostCard__eventDetails">
          <span class="GroupPostCard__eventTitle">{{ eventTitle }}</span>
          <span class="GroupPostCard__eventDateTime">{{ eventDateTime }}</span>
          <span class="GroupPostCard__eventAttendees">
            <span class="GroupPostCard__attendeeCount">{{ attendeeCount }}</span>
            <span class="GroupPostCard__attendeeLabel">people are going</span>
          </span>
        </div>
      </div>
    </div>

    <!-- Action bar (non-event posts) -->
    <div v-if="!isEvent" class="GroupPostCard__actions">
      <div class="GroupPostCard__actionsLeft">
        <span class="GroupPostCard__metric">
          <svg class="GroupPostCard__actionIcon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M12 5C5 5 2 12 2 12s3 7 10 7 10-7 10-7-3-7-10-7zm0 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8z" />
          </svg>
          <span class="GroupPostCard__metricValue">{{ viewCount }}</span>
        </span>
        <span class="GroupPostCard__metric">
          <svg class="GroupPostCard__actionIcon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M17 1l4 4-4 4" />
            <path d="M3 11V9a4 4 0 0 1 4-4h14" />
            <path d="M7 23l-4-4 4-4" />
            <path d="M21 13v2a4 4 0 0 1-4 4H3" />
          </svg>
          <span class="GroupPostCard__metricValue">{{ shareCount }}</span>
        </span>
      </div>
      <div class="GroupPostCard__actionsRight">
        <svg class="GroupPostCard__actionIcon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z" />
        </svg>
        <svg class="GroupPostCard__actionIcon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M12 15V3" />
          <path d="M8 7l4-4 4 4" />
          <path d="M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-7" />
        </svg>
      </div>
    </div>
  </div>
</template>
