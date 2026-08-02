<script lang="ts">
import { cva } from '../../../util/cva'

// SplitMonthCalendar — web twin of the iPhone calendar screen
// (Pages/Main/MainCalendar.swift → Components/Calendar/SplitMonthCalendar.swift
// + SplitMonthCalendarController/SplitMonthLayout/CalendarDayCell). Shared by
// BOTH the capture harness (inert, props seed everything) and the production
// LeaderApp calendar view (interactive + emits).
//
// Structure (iOS SplitMonthCalendarWithBar → ZStack):
//   • header — ALWAYS visible; PageTitle title-only (collapsed) or
//     backLinkTitle "Back" (expanded)
//   • weekday header "S M T W T F S" + an 8px appBackground→clear gradient —
//     collapsed ONLY
//   • body — either the continuous month grid (one section per month, no
//     spacing) or the expanded event list; the day tap plays the iOS
//     "curtain" split between them
//   • Today pill (CalendarBottomBar) — floats bottom-leading over BOTH states
//
// Grid geometry is a 1:1 port of SplitMonthLayout: 16px side padding,
// cellWidth = (W − 32) / 7, cell height 56, month header 32, and a 1px
// white@10% week separator at every row boundary EXCEPT after a month's last
// row. Only the month's own days are emitted (no leading/trailing padding
// days) — each is placed by weekdayIndex (column) / rowIndex (row), which is
// why the grid uses explicit grid-column/grid-row placement.
//
// CVA keys mirror the SCSS modifiers in
// resources/css/components/card/split-month-calendar.scss exactly.
export const SplitMonthCalendarCva = cva('SplitMonthCalendar', {
  variants: {},
  defaultVariants: {},
})
</script>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { classnames } from '../../../util/classnames'
import PageTitle from '../page-title/page-title.vue'
import CalendarWeekdayHeader from '../calendar-weekday-header/calendar-weekday-header.vue'
import CalendarDayCell from '../calendar-day-cell/calendar-day-cell.vue'
import CalendarBottomBar from '../calendar-bottom-bar/calendar-bottom-bar.vue'
import CardLesson from '../card-lesson/card-lesson.vue'

/** One month in the rendered window. `month` is 1-12. */
export interface SplitCalendarMonth {
  year: number
  month: number
}

/** A calendar event — one scheduled lesson (iOS SplitCalendarEvent). */
export interface SplitCalendarEvent {
  id: string
  /** Local date key, 'yyyy-MM-dd' (iOS buckets in the DEVICE timezone). */
  date: string
  /** Lesson dayNumber → the CardLesson DAY badge. */
  day: number
  /** iOS uses the STUDY PROGRAM NAME as the event title. */
  title: string
  /** Pre-formatted "EEEE, MMM d, yyyy" line; derived from `date` when absent. */
  dateLine?: string
  estimatedMinutes?: number
  activities?: Array<{ activityType: string }>
  /** Dot color — iOS stamps every event #6c47ff. */
  color?: string
}

interface Props {
  /** Header title, "MMM yyyy" of the topmost visible month. */
  title?: string
  /** The rendered month window (iOS: today ±12, grown ±6 on scroll). */
  months?: SplitCalendarMonth[]
  /** 'yyyy-MM-dd' — draws the today disc. Capture pins it; production passes
   *  the real local today. */
  todayKey?: string | null
  /** 'yyyy-MM-dd' — draws the 2px selection ring; also the event list anchor. */
  selectedKey?: string | null
  events?: SplitCalendarEvent[]
  /** Event-list mode (iOS isExpanded). */
  expanded?: boolean
  /** iOS isInitialLoading — opaque cover + centered spinner, no cache only. */
  loading?: boolean
  /** iOS bottomPadding: 80 when the NavBar is visible, else 16. */
  navBarVisible?: boolean
  showBottomBar?: boolean
  /** Production: taps/scroll become live. Capture never passes it. */
  interactive?: boolean
  // Capture-only: render the iOS device status bar. Production never passes it.
  statusBar?: boolean
  /** Capture-only: clear the 34pt home-indicator safe area under the Today
   *  pill (the iPhone page does; production has the NavBar instead). */
  homeIndicator?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  title: '',
  months: () => [],
  todayKey: null,
  selectedKey: null,
  events: () => [],
  expanded: false,
  loading: false,
  navBarVisible: true,
  showBottomBar: true,
  interactive: false,
  statusBar: false,
  homeIndicator: false,
})

const emit = defineEmits<{
  /** A day cell was tapped (iOS didSelectItemAt → split/collapse). */
  selectDay: [key: string]
  /** Back link while expanded (iOS controller.collapse()). */
  back: []
  /** Today pill — iOS clears the selection and scrolls to the current month. */
  today: []
  /** An event card was tapped (iOS → .lessonActionMenu). */
  eventTap: [id: string]
  /** Topmost visible month changed (iOS onScrolledToNewMonth → header title). */
  visibleMonth: [month: SplitCalendarMonth]
  /** Scrolled within 500px of either end (iOS grows the window by 6 months). */
  reachEdge: [edge: 'start' | 'end']
}>()

// ── Date helpers — ALL local-time (iOS buckets with the device timezone;
//    parsing 'yyyy-MM-dd' via new Date() would be UTC and shift a day) ──
function pad2(n: number): string {
  return String(n).padStart(2, '0')
}

function dateKey(year: number, month: number, day: number): string {
  return `${year}-${pad2(month)}-${pad2(day)}`
}

function parseKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number)
  return new Date(y, (m ?? 1) - 1, d ?? 1)
}

const MONTH_LONG = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December']
const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
const WEEKDAY_LONG = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
  'Friday', 'Saturday']

// ── Grid model (iOS SplitCalendarMonth.generate) ──
interface DayCellModel {
  day: number
  key: string
  column: number
  row: number
}

interface MonthModel {
  key: string
  name: string
  year: number
  cells: DayCellModel[]
  rows: number
}

const monthModels = computed<MonthModel[]>(() =>
  props.months.map((m) => {
    // iOS: firstWeekdayIndex = component(.weekday) − 1, i.e. Sunday-first,
    // hard-coded (NOT locale-derived).
    const firstWeekday = new Date(m.year, m.month - 1, 1).getDay()
    const daysInMonth = new Date(m.year, m.month, 0).getDate()
    const cells: DayCellModel[] = []
    for (let d = 1; d <= daysInMonth; d += 1) {
      const offset = firstWeekday + d - 1
      cells.push({
        day: d,
        key: dateKey(m.year, m.month, d),
        column: offset % 7,
        row: Math.floor(offset / 7),
      })
    }
    return {
      key: `${m.year}-${pad2(m.month)}`,
      name: MONTH_LONG[m.month - 1] ?? '',
      year: m.year,
      cells,
      rows: cells.length ? (cells[cells.length - 1]?.row ?? 0) + 1 : 0,
    }
  })
)

// Events bucketed by local date key (iOS AppState.calendarEvents).
const eventsByDate = computed<Record<string, SplitCalendarEvent[]>>(() => {
  const map: Record<string, SplitCalendarEvent[]> = {}
  for (const ev of props.events) {
    ;(map[ev.date] ??= []).push(ev)
  }
  return map
})

// iOS configureEventDots: max 3, and the color flips to white on the purple
// today disc / selection ring.
function dotsFor(key: string): string[] {
  return (eventsByDate.value[key] ?? []).map((e) => e.color ?? '#6c47ff')
}

// ── Expanded event list (iOS ExpandedEventListView) ──
interface DaySection {
  key: string
  name: string
  dateLabel: string
  isToday: boolean
  isPast: boolean
  events: SplitCalendarEvent[]
}

// iOS builds sections for selected − 1 … selected + 60 (62 days).
const SECTION_LEAD = 1
const SECTION_TRAIL = 60

const daySections = computed<DaySection[]>(() => {
  if (!props.selectedKey) return []
  const anchor = parseKey(props.selectedKey)
  const todayTs = props.todayKey ? parseKey(props.todayKey).getTime() : null
  const out: DaySection[] = []
  for (let i = -SECTION_LEAD; i <= SECTION_TRAIL; i += 1) {
    const d = new Date(anchor.getFullYear(), anchor.getMonth(), anchor.getDate() + i)
    const key = dateKey(d.getFullYear(), d.getMonth() + 1, d.getDate())
    out.push({
      key,
      name: WEEKDAY_LONG[d.getDay()] ?? '',
      dateLabel: `${MONTH_SHORT[d.getMonth()]} ${d.getDate()}`,
      isToday: todayTs != null && d.getTime() === todayTs,
      isPast: todayTs != null && d.getTime() < todayTs,
      events: eventsByDate.value[key] ?? [],
    })
  }
  return out
})

// iOS CardLesson date line: "EEEE, MMM d, yyyy".
function eventDateLine(ev: SplitCalendarEvent): string {
  if (ev.dateLine) return ev.dateLine
  const d = parseKey(ev.date)
  return `${WEEKDAY_LONG[d.getDay()]}, ${MONTH_SHORT[d.getMonth()]} ${d.getDate()}, ${d.getFullYear()}`
}

// ── Interaction (production only; capture binds nothing) ──
const scrollEl = ref<HTMLElement | null>(null)
const listEl = ref<HTMLElement | null>(null)

function onDayTap(key: string): void {
  if (!props.interactive) return
  emit('selectDay', key)
}

function onEventTap(id: string): void {
  if (!props.interactive) return
  emit('eventTap', id)
}

// iOS onScrolledToNewMonth: the topmost item at contentOffset + 80 decides the
// header title; and within 500pt of either end the month window grows.
const EDGE_THRESHOLD = 500
const TITLE_PROBE = 80

function onScroll(): void {
  if (!props.interactive) return
  const el = scrollEl.value
  if (!el) return

  if (el.scrollTop < EDGE_THRESHOLD) emit('reachEdge', 'start')
  else if (el.scrollHeight - el.scrollTop - el.clientHeight < EDGE_THRESHOLD) {
    emit('reachEdge', 'end')
  }

  const probe = el.scrollTop + TITLE_PROBE
  const sections = el.querySelectorAll<HTMLElement>('[data-month]')
  let current: HTMLElement | null = null
  for (const section of sections) {
    if (section.offsetTop <= probe) current = section
    else break
  }
  const attr = current?.dataset.month
  if (!attr) return
  const [y, m] = attr.split('-').map(Number)
  if (y && m) emit('visibleMonth', { year: y, month: m })
}

/** Scroll a month to the top of the viewport (iOS scrollToCurrentMonth). */
function scrollToMonth(year: number, month: number, smooth = false): void {
  const el = scrollEl.value
  if (!el) return
  const target = el.querySelector<HTMLElement>(`[data-month="${year}-${pad2(month)}"]`)
  if (target) el.scrollTo({ top: target.offsetTop, behavior: smooth ? 'smooth' : 'auto' })
}

defineExpose({ scrollToMonth })

// iOS auto-scrolls the expanded list to the selected date, anchor .top,
// un-animated.
watch(
  () => [props.expanded, props.selectedKey],
  async ([expanded]) => {
    if (!expanded || !props.interactive) return
    await nextTick()
    const el = listEl.value
    const target = el?.querySelector<HTMLElement>(
      `[data-day="${props.selectedKey}"]`
    )
    if (el && target) el.scrollTop = target.offsetTop
  }
)

const classes = computed(() =>
  classnames(
    SplitMonthCalendarCva.variants({}),
    props.expanded && 'SplitMonthCalendar--expanded',
    props.class
  )
)
</script>

<template>
  <div :class="classes">
    <!-- iOS device status bar (capture only; 62pt top safe-area inset). -->
    <div v-if="props.statusBar" class="SplitMonthCalendar__statusbar" aria-hidden="true">
      <span class="SplitMonthCalendar__clock">9:41</span>
      <span class="SplitMonthCalendar__indicators">
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" /><rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" /><rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <!-- Header: ALWAYS visible; the variant swaps with `expanded`. -->
    <div class="SplitMonthCalendar__header">
      <PageTitle
        v-if="props.expanded"
        factory="backLinkTitle"
        :title="props.title"
        back-text="Back"
        @left="emit('back')"
      />
      <PageTitle v-else :title="props.title" />

      <!-- Weekday row + gradient fade: collapsed only. -->
      <template v-if="!props.expanded">
        <CalendarWeekdayHeader class="SplitMonthCalendar__weekdays" />
        <div class="SplitMonthCalendar__fade" aria-hidden="true"></div>
      </template>
    </div>

    <div class="SplitMonthCalendar__body">
      <!-- ── Month grid (collapsed) ── -->
      <div
        v-show="!props.expanded"
        ref="scrollEl"
        class="SplitMonthCalendar__scroll"
        @scroll="onScroll"
      >
        <section
          v-for="m in monthModels"
          :key="m.key"
          class="SplitMonthCalendar__month"
          :data-month="m.key"
        >
          <!-- iOS CalendarMonthHeaderView: h32, leading, stack bottom-anchored −4. -->
          <header class="SplitMonthCalendar__monthHeader">
            <span class="SplitMonthCalendar__monthName">{{ m.name }}</span>
            <span class="SplitMonthCalendar__monthYear">{{ m.year }}</span>
          </header>

          <div
            class="SplitMonthCalendar__grid"
            :style="{ '--rows': m.rows }"
          >
            <!-- Week separators: 1px white@10% at each row boundary EXCEPT
                 after the month's last row (iOS skips row == rows − 1). -->
            <span
              v-for="r in Math.max(m.rows - 1, 0)"
              :key="`sep-${r}`"
              class="SplitMonthCalendar__separator"
              :style="{ top: `${r * 56 - 0.5}px` }"
              aria-hidden="true"
            ></span>

            <component
              :is="props.interactive ? 'button' : 'div'"
              v-for="cell in m.cells"
              :key="cell.key"
              :type="props.interactive ? 'button' : undefined"
              class="SplitMonthCalendar__cell"
              :style="{ gridColumn: cell.column + 1, gridRow: cell.row + 1 }"
              @click="onDayTap(cell.key)"
            >
              <CalendarDayCell
                :day-number="cell.day"
                :is-today="cell.key === props.todayKey"
                :is-selected="cell.key === props.selectedKey"
                :event-colors="dotsFor(cell.key)"
              />
            </component>
          </div>
        </section>
      </div>

      <!-- ── Expanded event list ── -->
      <div v-if="props.expanded" ref="listEl" class="SplitMonthCalendar__list">
        <div
          v-for="section in daySections"
          :key="section.key"
          class="SplitMonthCalendar__daySection"
          :data-day="section.key"
        >
          <div
            class="SplitMonthCalendar__dayHeader"
            :class="{
              'SplitMonthCalendar__dayHeader--today': section.isToday,
              'SplitMonthCalendar__dayHeader--past': section.isPast,
              'SplitMonthCalendar__dayHeader--empty': section.events.length === 0,
            }"
          >
            <span class="SplitMonthCalendar__dayName">{{ section.name }}</span>
            <span class="SplitMonthCalendar__dayDate">{{ section.dateLabel }}</span>
          </div>

          <component
            :is="props.interactive ? 'button' : 'div'"
            v-for="ev in section.events"
            :key="ev.id"
            :type="props.interactive ? 'button' : undefined"
            class="SplitMonthCalendar__event"
            :class="{ 'SplitMonthCalendar__event--past': section.isPast }"
            @click="onEventTap(ev.id)"
          >
            <CardLesson
              mode="lesson"
              :day="ev.day"
              :title="ev.title"
              :date="eventDateLine(ev)"
              :estimated-minutes="ev.estimatedMinutes"
              :activities="ev.activities ?? []"
            />
          </component>
        </div>
      </div>

      <!-- iOS: opaque cover + centered spinner, ONLY when there is no cache. -->
      <div v-if="props.loading" class="SplitMonthCalendar__loading">
        <span class="SplitMonthCalendar__spinner" aria-hidden="true"></span>
      </div>
    </div>

    <!-- Today pill — floats over BOTH states (iOS outer ZStack). -->
    <div
      v-if="props.showBottomBar"
      class="SplitMonthCalendar__bottomBar"
      :class="{
        'SplitMonthCalendar__bottomBar--navbar': props.navBarVisible,
        'SplitMonthCalendar__bottomBar--homeIndicator': props.homeIndicator,
      }"
      @click="props.interactive && emit('today')"
    >
      <CalendarBottomBar />
    </div>
  </div>
</template>
