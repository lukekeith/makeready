<script setup lang="ts">
// CalendarView — production host of the LeaderApp Calendar tab (iOS
// Pages/Main/MainCalendar.swift). Renders the shared SplitMonthCalendar twin
// interactively and owns the data + presentation:
//
//   • month window — iOS loads today ±12 months and grows by 6 whenever the
//     scroll comes within 500px of either end (trimmed to 50 months)
//   • day tap — selects the day and expands into the event list; tapping the
//     same day again (or Back) collapses, exactly like the iOS curtain split
//   • Today pill — clears the selection and scrolls back to the current month
//   • event tap — presents `.lessonActionMenu` with the iOS row set for THIS
//     page (no "Add Lesson" row): Edit Activities / Edit Enrollment /
//     Open Lesson / Share Lesson / Delete
//
// iOS presents `.editEnrollmentDay` as its own modal for "Edit Activities";
// on web the day editor lives inside the enrollment-schedule modal, so both
// edit rows present `.enrollmentSchedule` — Edit Activities seeds the day.
import { computed, onMounted, ref } from 'vue'
import SplitMonthCalendar, {
  type SplitCalendarMonth,
} from '../../../components/card/split-month-calendar/split-month-calendar.vue'
import LessonActionMenu from '../../../components/card/lesson-action-menu/lesson-action-menu.vue'
import EnrollmentScheduleModal from '../components/enrollment-schedule-modal.vue'
import { ROUTES } from '../overlay/overlay-routes'
import { useOverlayManager } from '../overlay/overlay.store'
import { useConfirmDialog } from '../overlay/confirm-dialog.store'
import { useLeaderCalendar, type CalendarEvent } from '../stores/leader-calendar.store'

const store = useLeaderCalendar()
const overlayManager = useOverlayManager()
const confirmDialog = useConfirmDialog()

const calendarRef = ref<InstanceType<typeof SplitMonthCalendar> | null>(null)

// ── Month window (iOS initialMonthRange 12, grows ±6, trimmed to 50) ──
const INITIAL_RANGE = 12
const GROW_BY = 6
const MAX_MONTHS = 50

function monthIndex(year: number, month: number): number {
  return year * 12 + (month - 1)
}

function fromIndex(index: number): SplitCalendarMonth {
  return { year: Math.floor(index / 12), month: (index % 12) + 1 }
}

const now = new Date()
const currentIndex = monthIndex(now.getFullYear(), now.getMonth() + 1)
const startIndex = ref(currentIndex - INITIAL_RANGE)
const endIndex = ref(currentIndex + INITIAL_RANGE)

const months = computed<SplitCalendarMonth[]>(() => {
  const out: SplitCalendarMonth[] = []
  for (let i = startIndex.value; i <= endIndex.value; i += 1) out.push(fromIndex(i))
  return out
})

function onReachEdge(edge: 'start' | 'end'): void {
  if (edge === 'start') {
    startIndex.value -= GROW_BY
    if (endIndex.value - startIndex.value + 1 > MAX_MONTHS) endIndex.value -= GROW_BY
  } else {
    endIndex.value += GROW_BY
    if (endIndex.value - startIndex.value + 1 > MAX_MONTHS) startIndex.value += GROW_BY
  }
}

// ── Header title (iOS onScrolledToNewMonth → "MMM yyyy") ──
const MONTH_SHORT = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const visibleMonth = ref<SplitCalendarMonth>({
  year: now.getFullYear(),
  month: now.getMonth() + 1,
})

const title = computed(
  () => `${MONTH_SHORT[visibleMonth.value.month - 1]} ${visibleMonth.value.year}`
)

const todayKey = computed(() => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate()
  ).padStart(2, '0')}`
})

// ── Selection / expansion (iOS split ⇄ collapse) ──
const selectedKey = ref<string | null>(null)
const expanded = ref(false)

function onSelectDay(key: string): void {
  // iOS: tapping the already-selected day collapses back to the grid.
  if (expanded.value && selectedKey.value === key) {
    collapse()
    return
  }
  selectedKey.value = key
  expanded.value = true
}

function collapse(): void {
  expanded.value = false
  selectedKey.value = null
}

function onToday(): void {
  // iOS: clears the selection, then scrolls to the current month.
  collapse()
  calendarRef.value?.scrollToMonth(now.getFullYear(), now.getMonth() + 1, true)
}

onMounted(async () => {
  await store.load()
  // iOS scrolls to the current month once the grid is built.
  calendarRef.value?.scrollToMonth(now.getFullYear(), now.getMonth() + 1)
})

// ── Event tap → .lessonActionMenu (iOS row set for this page) ──
const PENCIL_LINE =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M13 21h8"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4z"/></svg>'
const SLIDERS =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M4 7h10M18 7h2M4 12h4M12 12h8M4 17h8M16 17h4"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="12" r="2"/><circle cx="14" cy="17" r="2"/></svg>'
const SAFARI =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2.2 5-5 2.2 2.2-5z"/></svg>'
const SHARE_UP =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M12 14.5V3.5"/><path d="M8.2 7l3.8-3.8L15.8 7"/><path d="M5.5 11.5v7a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2v-7"/></svg>'
const TRASH =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16"/><path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"/><path d="M6 7l1 12.5A2 2 0 0 0 9 21.5h6a2 2 0 0 0 2-2L18 7"/><path d="M10 11v6.5M14 11v6.5"/></svg>'

// iOS MainCalendar passes NO "Add Lesson" row (unlike the schedule page).
const MENU_ITEMS = [
  { icon: PENCIL_LINE, title: 'Edit Activities' },
  { icon: SLIDERS, title: 'Edit Enrollment' },
  { icon: SAFARI, title: 'Open Lesson' },
  { icon: SHARE_UP, title: 'Share Lesson' },
  { icon: TRASH, title: 'Delete', style: 'destructive' as const },
]

function showError(message: string): void {
  void confirmDialog.confirm({
    title: 'Something went wrong',
    message,
    buttons: [{ label: 'OK', style: 'secondary' }],
  })
}

function dismissMenu(): void {
  overlayManager.dismiss(ROUTES.lessonActionMenu.id)
}

function onEventTap(id: string): void {
  const ev = store.eventById(id)
  if (!ev) return
  const d = new Date(ev.startTime)
  const dateLabel = d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
  overlayManager.present(ROUTES.lessonActionMenu, LessonActionMenu, {
    studyName: ev.title,
    subtitle: `Day ${ev.day} - ${dateLabel}`,
    items: MENU_ITEMS,
    onSelect: (i: number) => {
      dismissMenu()
      const label = MENU_ITEMS[i]?.title
      if (label === 'Edit Activities') openSchedule(ev, ev.scheduleId)
      else if (label === 'Edit Enrollment') openSchedule(ev)
      else if (label === 'Open Lesson') void openLesson(ev)
      else if (label === 'Share Lesson') void shareLesson(ev)
      else if (label === 'Delete') void requestDelete(ev)
    },
    onClose: dismissMenu,
  })
}

function openSchedule(ev: CalendarEvent, initialScheduleId?: string): void {
  overlayManager.present(ROUTES.enrollmentSchedule, EnrollmentScheduleModal, {
    enrollmentId: ev.enrollmentId,
    titleOverride: 'Lessons',
    initialScheduleId,
    onChanged: () => void store.load(true),
  })
}

async function openLesson(ev: CalendarEvent): Promise<void> {
  try {
    const url = await store.loadLessonInvite(ev.scheduleId)
    if (!url) throw new Error()
    window.open(url, '_blank', 'noopener')
  } catch {
    showError("Couldn't open the lesson") // iOS friendlyMessage, verbatim
  }
}

async function shareLesson(ev: CalendarEvent): Promise<void> {
  // iOS shares plain text: "Join Day {n} of {study} on MakeReady: {url}".
  try {
    const url = await store.loadLessonInvite(ev.scheduleId)
    const text = `Join Day ${ev.day} of ${ev.title} on MakeReady: ${url ?? ''}`
    if (navigator.share) await navigator.share({ text })
    else await navigator.clipboard.writeText(text)
  } catch {
    showError("Couldn't open the lesson")
  }
}

async function requestDelete(ev: CalendarEvent): Promise<void> {
  const choice = await confirmDialog.confirm({
    title: 'Delete Lesson?',
    message: `Are you sure you want to permanently delete Day ${ev.day} of ${ev.title} from the enrollment schedule?`,
    buttons: [
      { label: 'Delete', style: 'destructive' },
      { label: 'Cancel', style: 'secondary' },
    ],
  })
  if (choice !== 0) return
  try {
    await store.deleteLessonSchedule(ev.enrollmentId, ev.scheduleId)
    if (expanded.value && !store.events.some((e) => e.date === selectedKey.value)) collapse()
  } catch {
    showError("Couldn't delete the lesson") // iOS friendlyMessage, verbatim
  }
}

const twinEvents = computed(() =>
  store.events.map((e) => ({
    id: e.id,
    date: e.date,
    day: e.day,
    title: e.title,
    estimatedMinutes: e.estimatedMinutes,
    activities: e.activities,
    color: e.color,
  }))
)
</script>

<template>
  <SplitMonthCalendar
    ref="calendarRef"
    interactive
    class="CalendarView"
    :title="title"
    :months="months"
    :today-key="todayKey"
    :selected-key="selectedKey"
    :events="twinEvents"
    :expanded="expanded"
    :loading="store.loading && !store.loaded"
    @select-day="onSelectDay"
    @back="collapse"
    @today="onToday"
    @event-tap="onEventTap"
    @visible-month="visibleMonth = $event"
    @reach-edge="onReachEdge"
  />
</template>

<style scoped>
/* The shell's view slot is a padded scroll container; the calendar owns its
   own scrolling, so it fills the slot's padding box instead (spanning under
   the fixed NavBar, like iOS). */
.CalendarView {
  position: absolute;
  inset: 0;
  height: auto;
}

/* iOS keeps the Today pill 80pt above the safe area, i.e. ~26pt clear of the
   NavBar. The shell's nav is --footer-height tall, so match that clearance
   here rather than in the twin (whose 80px default is what capture renders). */
.CalendarView :deep(.SplitMonthCalendar__bottomBar--navbar) {
  bottom: calc(var(--footer-height) + 8px);
}
</style>
