<script setup lang="ts">
import { computed } from 'vue'
import { classnames } from '../../../util/classnames'
import IconButton from '../../primitive/icon-button/icon-button.vue'

// Calendar — split-month calendar (iOS SplitMonthCalendar parity). A month grid
// plus the selected day's event list. No CVA: there are no real variants.
//
// Pure Date math only (native Date API). The displayed month is driven entirely
// by the `month` prop ({ year, month } 0-indexed) so nothing relies on "today".

interface MonthValue {
  year: number
  /** 0-indexed month (0 = January, 11 = December). */
  month: number
}

interface CalendarEvent {
  /** ISO date string (YYYY-MM-DD). */
  date: string
  title: string
  /** Optional display time, e.g. "9:00 AM". */
  time?: string
}

interface Props {
  /** Controls the displayed month. v-model:month. */
  month: MonthValue
  /** Currently selected day as an ISO date string (YYYY-MM-DD). */
  selected?: string
  events?: CalendarEvent[]
  /** ISO dates that get an event dot even without a full event entry. */
  markedDates?: string[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  selected: undefined,
  events: () => [],
  markedDates: () => [],
  class: undefined,
})

const emit = defineEmits<{
  'update:month': [MonthValue]
  select: [string]
}>()

const WEEKDAYS = ['S', 'M', 'T', 'W', 'T', 'F', 'S']
const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

// ─── ISO helpers (local, no timezone surprises) ──────────────────────────────
function toIso(year: number, month: number, day: number): string {
  const mm = String(month + 1).padStart(2, '0')
  const dd = String(day).padStart(2, '0')
  return `${year}-${mm}-${dd}`
}

const monthLabel = computed(
  () => `${MONTH_NAMES[props.month.month]} ${props.month.year}`
)

// Set of ISO dates that should show an event dot (events + markedDates).
const markedSet = computed(() => {
  const set = new Set<string>(props.markedDates)
  for (const e of props.events) set.add(e.date)
  return set
})

interface DayCell {
  iso: string
  day: number
  inMonth: boolean
  isSelected: boolean
  hasEvent: boolean
}

// 6 weeks × 7 days, leading/trailing days from adjacent months. Pure Date math.
const weeks = computed<DayCell[][]>(() => {
  const { year, month } = props.month
  const firstOfMonth = new Date(year, month, 1)
  const startWeekday = firstOfMonth.getDay() // 0 = Sunday
  const daysInMonth = new Date(year, month + 1, 0).getDate()
  const daysInPrevMonth = new Date(year, month, 0).getDate()

  const cells: DayCell[] = []

  // Leading days from the previous month.
  for (let i = 0; i < startWeekday; i++) {
    const day = daysInPrevMonth - startWeekday + 1 + i
    const d = new Date(year, month - 1, day)
    const iso = toIso(d.getFullYear(), d.getMonth(), d.getDate())
    cells.push({
      iso,
      day,
      inMonth: false,
      isSelected: iso === props.selected,
      hasEvent: markedSet.value.has(iso),
    })
  }

  // Days of the current month.
  for (let day = 1; day <= daysInMonth; day++) {
    const iso = toIso(year, month, day)
    cells.push({
      iso,
      day,
      inMonth: true,
      isSelected: iso === props.selected,
      hasEvent: markedSet.value.has(iso),
    })
  }

  // Trailing days from the next month to fill a 6×7 grid (42 cells).
  let nextDay = 1
  while (cells.length < 42) {
    const d = new Date(year, month + 1, nextDay)
    const iso = toIso(d.getFullYear(), d.getMonth(), d.getDate())
    cells.push({
      iso,
      day: nextDay,
      inMonth: false,
      isSelected: iso === props.selected,
      hasEvent: markedSet.value.has(iso),
    })
    nextDay++
  }

  // Chunk into weeks of 7.
  const result: DayCell[][] = []
  for (let i = 0; i < cells.length; i += 7) {
    result.push(cells.slice(i, i + 7))
  }
  return result
})

// Events for the selected day (chronological-ish: input order, time first).
const selectedEvents = computed(() =>
  props.selected ? props.events.filter((e) => e.date === props.selected) : []
)

const selectedLabel = computed(() => {
  if (!props.selected) return ''
  const [y, m, d] = props.selected.split('-').map(Number)
  const date = new Date(y, m - 1, d)
  const weekday = date.toLocaleDateString('en-US', { weekday: 'long' })
  return `${weekday}, ${MONTH_NAMES[m - 1]} ${d}`
})

function shiftMonth(delta: number) {
  const next = new Date(props.month.year, props.month.month + delta, 1)
  emit('update:month', { year: next.getFullYear(), month: next.getMonth() })
}

function onSelect(cell: DayCell) {
  emit('select', cell.iso)
}

const rootClass = computed(() => classnames('Calendar', props.class))
</script>

<template>
  <div :class="rootClass">
    <!-- Header: month/year with prev/next nav -->
    <div class="Calendar__header">
      <IconButton
        variant="Default"
        size="Sm"
        :ariaLabel="`Previous month, ${monthLabel}`"
        @click="shiftMonth(-1)"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M15 18l-6-6 6-6" />
        </svg>
      </IconButton>

      <span class="Calendar__title">{{ monthLabel }}</span>

      <IconButton
        variant="Default"
        size="Sm"
        :ariaLabel="`Next month, ${monthLabel}`"
        @click="shiftMonth(1)"
      >
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <path d="M9 18l6-6-6-6" />
        </svg>
      </IconButton>
    </div>

    <!-- Day-of-week header -->
    <div class="Calendar__weekdays" aria-hidden="true">
      <span v-for="(d, i) in WEEKDAYS" :key="i" class="Calendar__weekday">{{ d }}</span>
    </div>

    <!-- Month grid -->
    <div class="Calendar__grid" role="grid">
      <div v-for="(week, wi) in weeks" :key="wi" class="Calendar__week" role="row">
        <button
          v-for="cell in week"
          :key="cell.iso"
          type="button"
          role="gridcell"
          class="Calendar__day"
          :class="{
            'Calendar__day--outside': !cell.inMonth,
            'Calendar__day--selected': cell.isSelected,
          }"
          :aria-label="cell.iso"
          :aria-selected="cell.isSelected || undefined"
          @click="onSelect(cell)"
        >
          <span class="Calendar__day-number">{{ cell.day }}</span>
          <span
            v-if="cell.hasEvent"
            class="Calendar__day-dot"
            aria-hidden="true"
          />
        </button>
      </div>
    </div>

    <!-- Selected day's event list (the "split" half of split-month) -->
    <div class="Calendar__events">
      <div v-if="selected" class="Calendar__events-heading">{{ selectedLabel }}</div>
      <ul v-if="selectedEvents.length" class="Calendar__event-list">
        <li v-for="(e, i) in selectedEvents" :key="i" class="Calendar__event">
          <span v-if="e.time" class="Calendar__event-time">{{ e.time }}</span>
          <span class="Calendar__event-title">{{ e.title }}</span>
        </li>
      </ul>
      <p v-else class="Calendar__events-empty">
        {{ selected ? 'No events' : 'Select a day to see events' }}
      </p>
    </div>
  </div>
</template>
