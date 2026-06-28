<script setup lang="ts">
// CalendarEventListContent — the day's event list shown in the split-calendar
// "gap" (iOS CalendarEventListContent parity). Fully data-driven via props.
//
// Layout (mirrors CalendarEventListView.swift):
//   • A date header ("Thursday, January 29", pre-formatted by the adapter).
//   • Empty state — a calendar-plus glyph + "No events" — when no events.
//   • Otherwise a list of scheduled-lesson cards (DAY indicator + title + a row
//     of neutral activity-icon boxes + a time estimate). Each event maps to a
//     CardLesson in `.lesson` mode, but the calendar passes the literal activity
//     icon (book / play / pray) in a neutral box rather than a type-derived
//     colored box, so the card body is rendered inline here.
//
// The iPhone wraps the list in a ScrollView, so its sizeThatFits snapshot
// collapses the list to ~0 height (only the header shows). The web twin renders
// the real cards — a documented parity gap, not a faithful pixel match for the
// Lessons variant.
//
// Class names mirror the BEM structure in
// resources/css/components/card/calendar-event-list-content.scss.
import { computed } from 'vue'

export interface CalendarEventActivity {
  icon: string // inline SVG markup (literal activity glyph)
  label?: string
}

export interface CalendarEvent {
  id: string
  title: string
  dayNumber: number
  coverImageUrl?: string
  date?: string // pre-formatted date line (omitted when absent)
  estimatedMinutes?: number
  activities?: CalendarEventActivity[]
}

interface Props {
  dateHeader: string
  events?: CalendarEvent[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  events: () => [],
})

const MAX_VISIBLE = 5

// calendar.badge.plus — empty-state glyph (single-color, follows currentColor).
const CALENDAR_PLUS_ICON =
  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 2a1 1 0 0 1 1 1v1h8V3a1 1 0 1 1 2 0v1h1a3 3 0 0 1 3 3v2H3V7a3 3 0 0 1 3-3h0V3a1 1 0 0 1 1-1zM3 11h11.26A6.5 6.5 0 0 0 11 17c0 1.13.29 2.2.8 3.13A2.99 2.99 0 0 1 6 19v-7H3v-1zm6 1.5a1 1 0 1 0 0 2 1 1 0 0 0 0-2zM6.5 14a1 1 0 1 0 0 2 1 1 0 0 0 0-2zM17.5 12a5.5 5.5 0 1 1 0 11 5.5 5.5 0 0 1 0-11zm0 2.25a.75.75 0 0 0-.75.75v1.75H15a.75.75 0 0 0 0 1.5h1.75V20a.75.75 0 0 0 1.5 0v-1.75H20a.75.75 0 0 0 0-1.5h-1.75V15a.75.75 0 0 0-.75-.75z"/></svg>'

function visible(event: CalendarEvent) {
  return (event.activities ?? []).slice(0, MAX_VISIBLE)
}
function overflow(event: CalendarEvent) {
  return Math.max(0, (event.activities ?? []).length - MAX_VISIBLE)
}
function estimateLabel(event: CalendarEvent) {
  const m = event.estimatedMinutes ?? 0
  if (m > 99) return '>99 min'
  if (m <= 0) return '0 min'
  return `${m} min`
}

const hasEvents = computed(() => props.events.length > 0)
</script>

<template>
  <div class="CalendarEventListContent" :class="props.class">
    <div class="CalendarEventListContent__header">{{ dateHeader }}</div>

    <!-- ─── Empty state ──────────────────────────────────────────────────── -->
    <div v-if="!hasEvents" class="CalendarEventListContent__empty">
      <span class="CalendarEventListContent__emptyIcon" v-html="CALENDAR_PLUS_ICON" />
      <span class="CalendarEventListContent__emptyText">No events</span>
    </div>

    <!-- ─── Event list (scheduled-lesson cards) ──────────────────────────── -->
    <div v-else class="CalendarEventListContent__list">
      <div
        v-for="event in events"
        :key="event.id"
        class="CalendarEventListContent__card"
      >
        <div
          v-if="event.coverImageUrl"
          class="CalendarEventListContent__cardCover"
          :style="{ backgroundImage: `url(${event.coverImageUrl})` }"
          aria-hidden="true"
        />
        <div class="CalendarEventListContent__day">
          <span class="CalendarEventListContent__dayLabel">DAY</span>
          <span class="CalendarEventListContent__dayNumber">{{ event.dayNumber }}</span>
        </div>
        <div class="CalendarEventListContent__body">
          <h3 v-if="event.title" class="CalendarEventListContent__title">{{ event.title }}</h3>
          <span v-if="event.date" class="CalendarEventListContent__date">{{ event.date }}</span>
          <div v-if="(event.activities ?? []).length" class="CalendarEventListContent__iconRow">
            <span
              v-for="(a, i) in visible(event)"
              :key="i"
              class="CalendarEventListContent__box"
              v-html="a.icon"
            />
            <span v-if="overflow(event)" class="CalendarEventListContent__overflow">
              +{{ overflow(event) }}
            </span>
            <span class="CalendarEventListContent__estimate">{{ estimateLabel(event) }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
