<script setup lang="ts">
// EnrollCalendar — web twin of the iPhone enrollment date picker's UIKit
// calendar (SelectEnrollDatePage.swift: EnrollCalendarRepresentable +
// EnrollCalendarLayout + EnrollDayCell + WeekHighlightDecorationView).
//
// A vertical list of month sections (iOS renders 12 months forward from
// today). Geometry from EnrollCalendarLayout: 16px horizontal padding,
// month header 48px (month s17 bold + year s17 white@50, 4px gap), weekday
// header 32px ("SUN MON TUES WED THU FRI SAT", 12px bold — white@50 for
// enabled weekdays, white@20 disabled), day rows 56px (cell width =
// (width-32)/7), 16px gap after each month.
//
// Day cell layers (bottom→top):
//   • week-range highlight — #3D2C8C bar, radius 22.5, behind the cells
//     (zIndex -1), spanning the selected range's cells per week row
//   • ghost circle 40px — existing scheduled lesson dates (white@10% future,
//     systemYellow@22% past)
//   • override circle 36px w/ 1px border — green #57DB8C (day added) /
//     pink #DE3F87 (day removed)
//   • start/end circle 45px brandPrimary
//   • day label 14px bold, nudged up 3px (iOS centerY constant -3)
//
// Deterministic: `startMonth` ("yyyy-MM") + `today` ("yyyy-MM-dd") are
// injectable so captures never depend on the wall clock; production omits
// them. All date math is local-tz string-key based (no Date parsing of ISO
// strings — see compare-date-range-local-tz).
import { computed } from 'vue'

interface Props {
  /** First rendered month, "yyyy-MM". Default = the current month. */
  startMonth?: string
  /** Months rendered forward (iOS generates 12). */
  monthCount?: number
  /** "Today" for min-date dimming, "yyyy-MM-dd". Default = the wall clock. */
  today?: string
  /** Selected range, "yyyy-MM-dd" keys. */
  startDate?: string | null
  endDate?: string | null
  /** Enabled weekdays, 0=Sun…6=Sat (iOS default Mon–Fri). */
  enabledDays?: number[]
  /** Per-day overrides ("yyyy-MM-dd"): flips that day's inclusion. */
  overriddenDates?: string[]
  /** Existing scheduled lesson dates (ghost circles), "yyyy-MM-dd". */
  existingLessonDates?: string[]
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  startMonth: '',
  monthCount: 12,
  today: '',
  startDate: null,
  endDate: null,
  enabledDays: () => [1, 2, 3, 4, 5],
  overriddenDates: () => [],
  existingLessonDates: () => [],
})

const emit = defineEmits<{
  selectDate: [key: string]
  longpressDate: [key: string]
}>()

const WEEKDAY_LABELS = ['SUN', 'MON', 'TUES', 'WED', 'THU', 'FRI', 'SAT']
const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
]

function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`
}

function keyOf(y: number, m: number, d: number): string {
  return `${y}-${pad2(m)}-${pad2(d)}`
}

const todayKey = computed(() => {
  if (props.today) return props.today
  const now = new Date()
  return keyOf(now.getFullYear(), now.getMonth() + 1, now.getDate())
})

const firstMonth = computed<{ y: number; m: number }>(() => {
  if (props.startMonth) {
    const [y, m] = props.startMonth.split('-').map(Number)
    return { y, m }
  }
  const now = new Date()
  return { y: now.getFullYear(), m: now.getMonth() + 1 }
})

const overridden = computed(() => new Set(props.overriddenDates))
const existing = computed(() => new Set(props.existingLessonDates))
const enabledSet = computed(() => new Set(props.enabledDays))

// A day is "included" in the schedule when its weekday is enabled XOR it is
// overridden (iOS EnrollmentDateState.isIncluded).
function isIncluded(key: string, weekday: number): boolean {
  const enabled = enabledSet.value.has(weekday)
  return overridden.value.has(key) ? !enabled : enabled
}

interface DayCell {
  key: string | null // null = leading/trailing blank slot
  day: number
  weekday: number
  isStart: boolean
  isEnd: boolean
  inRange: boolean
  included: boolean
  past: boolean
  ghost: '' | 'future' | 'past'
  override: '' | 'added' | 'removed'
}

interface WeekRow {
  cells: DayCell[]
  // Range-highlight span, 0-based inclusive column indices (null = none).
  hlFrom: number | null
  hlTo: number | null
}

interface MonthSection {
  name: string
  year: number
  weeks: WeekRow[]
}

const months = computed<MonthSection[]>(() => {
  const out: MonthSection[] = []
  const start = props.startDate
  const end = props.endDate
  let { y, m } = firstMonth.value
  for (let i = 0; i < props.monthCount; i++) {
    const daysInMonth = new Date(y, m, 0).getDate()
    const firstWeekday = new Date(y, m - 1, 1).getDay()
    const cells: DayCell[] = []
    for (let b = 0; b < firstWeekday; b++) {
      cells.push({
        key: null, day: 0, weekday: b, isStart: false, isEnd: false,
        inRange: false, included: false, past: false, ghost: '', override: '',
      })
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const key = keyOf(y, m, d)
      const weekday = (firstWeekday + d - 1) % 7
      const past = key < todayKey.value
      const inRange = !!start && !!end && key >= start && key <= end
      const hasOverride = overridden.value.has(key)
      cells.push({
        key,
        day: d,
        weekday,
        isStart: key === start,
        isEnd: key === end,
        inRange,
        included: isIncluded(key, weekday),
        past,
        ghost: existing.value.has(key) ? (past ? 'past' : 'future') : '',
        override: hasOverride ? (enabledSet.value.has(weekday) ? 'removed' : 'added') : '',
      })
    }
    while (cells.length % 7 !== 0) {
      cells.push({
        key: null, day: 0, weekday: cells.length % 7, isStart: false,
        isEnd: false, inRange: false, included: false, past: false,
        ghost: '', override: '',
      })
    }
    const weeks: WeekRow[] = []
    for (let w = 0; w < cells.length / 7; w++) {
      const rowCells = cells.slice(w * 7, w * 7 + 7)
      let hlFrom: number | null = null
      let hlTo: number | null = null
      rowCells.forEach((c, idx) => {
        if (c.inRange) {
          if (hlFrom === null) hlFrom = idx
          hlTo = idx
        }
      })
      weeks.push({ cells: rowCells, hlFrom, hlTo })
    }
    out.push({ name: MONTH_NAMES[m - 1], year: y, weeks })
    m += 1
    if (m > 12) {
      m = 1
      y += 1
    }
  }
  return out
})

// Long-press support (production; captures never interact).
let pressTimer: ReturnType<typeof setTimeout> | null = null
let longpressFired = false

function onPointerDown(key: string | null): void {
  if (!key) return
  longpressFired = false
  pressTimer = setTimeout(() => {
    longpressFired = true
    emit('longpressDate', key)
  }, 500)
}

function onPointerUp(key: string | null): void {
  if (pressTimer) {
    clearTimeout(pressTimer)
    pressTimer = null
  }
  if (!key || longpressFired) return
  emit('selectDate', key)
}

function onPointerCancel(): void {
  if (pressTimer) {
    clearTimeout(pressTimer)
    pressTimer = null
  }
}
</script>

<template>
  <div :class="['EnrollCalendar', props.class]">
    <section
      v-for="(month, mi) in months"
      :key="mi"
      class="EnrollCalendar__month"
    >
      <div class="EnrollCalendar__monthHeader">
        <span class="EnrollCalendar__monthName">{{ month.name }}</span>
        <span class="EnrollCalendar__monthYear">{{ month.year }}</span>
      </div>

      <div class="EnrollCalendar__weekdays">
        <span
          v-for="(label, wi) in WEEKDAY_LABELS"
          :key="wi"
          class="EnrollCalendar__weekday"
          :class="{ 'EnrollCalendar__weekday--disabled': !enabledSet.has(wi) }"
          >{{ label }}</span
        >
      </div>

      <div
        v-for="(week, wki) in month.weeks"
        :key="wki"
        class="EnrollCalendar__week"
      >
        <div
          v-if="week.hlFrom !== null && week.hlTo !== null"
          class="EnrollCalendar__rangeBar"
          :style="{
            left: `${(week.hlFrom / 7) * 100}%`,
            width: `${((week.hlTo - week.hlFrom + 1) / 7) * 100}%`,
          }"
        ></div>

        <button
          v-for="(cell, ci) in week.cells"
          :key="ci"
          type="button"
          class="EnrollCalendar__cell"
          :disabled="!cell.key"
          @pointerdown="onPointerDown(cell.key)"
          @pointerup="onPointerUp(cell.key)"
          @pointerleave="onPointerCancel"
          @pointercancel="onPointerCancel"
          @contextmenu.prevent
        >
          <template v-if="cell.key">
            <span
              v-if="cell.ghost"
              class="EnrollCalendar__ghost"
              :class="`EnrollCalendar__ghost--${cell.ghost}`"
            ></span>
            <span
              v-if="cell.override"
              class="EnrollCalendar__override"
              :class="`EnrollCalendar__override--${cell.override}`"
            ></span>
            <span
              v-if="cell.isStart || cell.isEnd"
              class="EnrollCalendar__terminal"
            ></span>
            <span
              class="EnrollCalendar__day"
              :class="{
                'EnrollCalendar__day--muted': cell.past || (!cell.included && !cell.isStart && !cell.isEnd),
              }"
              >{{ cell.day }}</span
            >
          </template>
        </button>
      </div>
    </section>
  </div>
</template>
