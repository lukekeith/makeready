<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import timeline from './timeline-data.json'
import './investor-timeline.scss'

interface Epic {
  id: string
  name: string
  lane: string
  start: string
  end: string
  status: 'done' | 'in-progress' | 'planned' | 'proposed'
  apps?: { name: string; weeks?: number; commits?: number }[]
  commits?: number
  weeks?: number
  description: string
  deliverables?: string[]
  dependsOn?: string[]
  userStories?: string[]
  tokens?: { processedM: number; outputM: number; extraCostUsd: number }
  milestones?: { date: string; label: string }[]
  progress?: { pct: number; note?: string }
  row?: string
  phases?: { name: string; meta?: string; summary: string }[]
}

interface Lane {
  id: string
  name: string
  color: string
}

const lanes = timeline.lanes as Lane[]
const epics = timeline.epics as Epic[]
const meta = timeline.meta

const DAY = 24 * 60 * 60 * 1000
const TODAY = meta.generated

function toDate(s: string): Date {
  return new Date(`${s}T00:00:00`)
}

// Range extends past the data so the canvas can over-scroll — on desktop
// content near the edges must pan clear of the floating detail panel; on
// mobile the modal is full screen, so one month of padding is enough.
const rangeStart = computed(() => {
  const min = epics.reduce((m, e) => (e.start < m ? e.start : m), epics[0].start)
  const d = toDate(min)
  return new Date(d.getFullYear(), d.getMonth() - (isMobile.value ? 1 : 3), 1)
})

const rangeEnd = computed(() => {
  const max = epics.reduce((m, e) => (e.end > m ? e.end : m), epics[0].end)
  const d = toDate(max)
  return new Date(d.getFullYear(), d.getMonth() + (isMobile.value ? 2 : 10), 1)
})

const totalDays = computed(() => (rangeEnd.value.getTime() - rangeStart.value.getTime()) / DAY)

// ── Zoom & pan (Linear-style) ─────────────────────────────
const DEFAULT_VISIBLE_DAYS = 84 // 12 weeks in the viewport
const MIN_VISIBLE_DAYS = 21 // 3 weeks — max zoom in
const visibleDays = ref(DEFAULT_VISIBLE_DAYS)
const wrapEl = ref<HTMLElement | null>(null)
const dragging = ref(false)
let suppressClick = false
const dragState = { active: false, pointerId: 0, startX: 0, startY: 0, startLeft: 0, startTop: 0 }

const isMobile = ref(typeof window !== 'undefined' && window.innerWidth <= 640)

const contentWidthPct = computed(() => (totalDays.value / visibleDays.value) * 100)
// Fewer axis labels on small screens: hide week ticks earlier on phones.
const showWeeks = computed(() => visibleDays.value <= (isMobile.value ? 60 : 190))

function clampDays(d: number): number {
  // Cap zoom-out so the canvas always keeps at least a detail-panel's width of
  // pannable overflow — content can be dragged clear of the panel at any zoom.
  // On mobile the modal is full screen, so the whole range may be shown.
  const wrap = wrapEl.value
  const overflowFactor = isMobile.value ? 1 : 1 + 440 / (wrap?.clientWidth || 1200)
  const maxDays = totalDays.value / overflowFactor
  return Math.min(Math.max(d, MIN_VISIBLE_DAYS), maxDays)
}

async function applyZoom(next: number, anchorFrac: number, viewportX: number) {
  const wrap = wrapEl.value
  if (!wrap) return
  visibleDays.value = next
  await nextTick()
  wrap.scrollLeft = anchorFrac * wrap.scrollWidth - viewportX
}

async function onWheel(e: WheelEvent) {
  const wrap = wrapEl.value
  if (!wrap) return
  // Horizontal wheel/trackpad motion pans natively; vertical wheel zooms.
  if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return
  e.preventDefault()
  const next = clampDays(visibleDays.value * Math.exp(e.deltaY * 0.0015))
  if (next === visibleDays.value) return
  const rect = wrap.getBoundingClientRect()
  const cursorX = e.clientX - rect.left
  const frac = (wrap.scrollLeft + cursorX) / wrap.scrollWidth
  await applyZoom(next, frac, cursorX)
}

// Smoothly animate to a zoom preset, anchored at the viewport center (Linear's M/Q/Y feel)
let zoomAnim = 0
function animateZoomTo(target: number, duration = 220) {
  const wrap = wrapEl.value
  if (!wrap) return
  target = clampDays(target)
  const from = visibleDays.value
  if (target === from) return
  const centerX = wrap.clientWidth / 2
  const frac = (wrap.scrollLeft + centerX) / wrap.scrollWidth
  const t0 = performance.now()
  cancelAnimationFrame(zoomAnim)
  const step = async (t: number) => {
    const p = Math.min(1, (t - t0) / duration)
    const ease = 1 - Math.pow(1 - p, 3)
    await applyZoom(from + (target - from) * ease, frac, centerX)
    if (p < 1) zoomAnim = requestAnimationFrame(step)
  }
  zoomAnim = requestAnimationFrame(step)
}

function scrollToToday() {
  const wrap = wrapEl.value
  if (!wrap) return
  wrap.scrollTo({
    left: (todayPct.value / 100) * wrap.scrollWidth - wrap.clientWidth * 0.3,
    behavior: 'smooth',
  })
}

function onKeydown(e: KeyboardEvent) {
  if (e.metaKey || e.ctrlKey || e.altKey) return
  const target = e.target as HTMLElement | null
  if (target && /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName)) return
  switch (e.key.toLowerCase()) {
    case 't': scrollToToday(); break
    case 'm': animateZoomTo(35); break
    case 'q': animateZoomTo(92); break
    case 'y': animateZoomTo(365); break
    case '0': animateZoomTo(DEFAULT_VISIBLE_DAYS); break
    case '-': animateZoomTo(visibleDays.value * 1.3, 120); break
    case '=':
    case '+': animateZoomTo(visibleDays.value / 1.3, 120); break
    case 'escape':
      if (budgetSheet.value || filterMenu.value) {
        budgetSheet.value = false
        filterMenu.value = false
      } else {
        selected.value = null
      }
      break
  }
}

// Click-off dismissal for the header/controls popups (budget sheet, filter menu)
function onDocClick(e: MouseEvent) {
  const t = e.target as HTMLElement | null
  if (!t) return
  if (budgetSheet.value && !t.closest('.InvestorTimeline__budgetSheet') && !t.closest('.InvestorTimeline__kpi--tap')) {
    budgetSheet.value = false
  }
  if (filterMenu.value && !t.closest('.InvestorTimeline__filterWrap')) {
    filterMenu.value = false
  }
}

function toggleBudgetSheet() {
  budgetSheet.value = !budgetSheet.value
  filterMenu.value = false
}

function toggleFilterMenu() {
  filterMenu.value = !filterMenu.value
  budgetSheet.value = false
}

// Clicking empty canvas dismisses the detail panel (bar/label clicks select instead)
function onCanvasClick(e: MouseEvent) {
  if (suppressClick) return
  const t = e.target as HTMLElement | null
  if (
    t &&
    (t.closest('.InvestorTimeline__bar') ||
      t.closest('.InvestorTimeline__rowLabel') ||
      t.closest('.InvestorTimeline__milestone'))
  ) return
  selected.value = null
}

const canvasW = ref(1200)

function onResize() {
  if (wrapEl.value) canvasW.value = wrapEl.value.clientWidth
  isMobile.value = window.innerWidth <= 640
}

onMounted(() => {
  window.addEventListener('keydown', onKeydown)
  window.addEventListener('resize', onResize)
  document.addEventListener('click', onDocClick)
  // Registered manually so they can be non-passive (preventDefault must work)
  const wrap = wrapEl.value
  if (wrap) {
    wrap.addEventListener('touchstart', onTouchStart, { passive: false })
    wrap.addEventListener('touchmove', onTouchMove, { passive: false })
    wrap.addEventListener('touchend', onTouchEnd)
    wrap.addEventListener('touchcancel', onTouchEnd)
  }
  onResize()
})
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('resize', onResize)
  document.removeEventListener('click', onDocClick)
  const wrap = wrapEl.value
  if (wrap) {
    wrap.removeEventListener('touchstart', onTouchStart)
    wrap.removeEventListener('touchmove', onTouchMove)
    wrap.removeEventListener('touchend', onTouchEnd)
    wrap.removeEventListener('touchcancel', onTouchEnd)
  }
})

// ── Pinch-to-zoom (touch) ─────────────────────────────────
// The page disables browser zoom (user-scalable=no), so two-finger pinch on
// the canvas drives the same visibleDays zoom, anchored at the pinch center.
const pinch = { active: false, startDist: 0, startVisible: 0, anchorFrac: 0, anchorX: 0 }

function touchDist(e: TouchEvent): number {
  const [a, b] = [e.touches[0], e.touches[1]]
  return Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY)
}

function onTouchStart(e: TouchEvent) {
  const wrap = wrapEl.value
  if (e.touches.length !== 2 || !wrap) return
  e.preventDefault()
  const rect = wrap.getBoundingClientRect()
  const midX = (e.touches[0].clientX + e.touches[1].clientX) / 2 - rect.left
  pinch.active = true
  pinch.startDist = touchDist(e)
  pinch.startVisible = visibleDays.value
  pinch.anchorX = midX
  pinch.anchorFrac = (wrap.scrollLeft + midX) / wrap.scrollWidth
  hover.value = null
}

function onTouchMove(e: TouchEvent) {
  if (!pinch.active || e.touches.length !== 2) return
  e.preventDefault()
  const dist = touchDist(e)
  if (!dist || !pinch.startDist) return
  // Fingers spreading → dist grows → fewer visible days (zoom in)
  const next = clampDays(pinch.startVisible * (pinch.startDist / dist))
  if (next !== visibleDays.value) applyZoom(next, pinch.anchorFrac, pinch.anchorX)
}

function onTouchEnd(e: TouchEvent) {
  if (e.touches.length < 2) pinch.active = false
}

function onPointerDown(e: PointerEvent) {
  if (e.pointerType !== 'mouse' || e.button !== 0 || !wrapEl.value) return
  dragState.active = true
  dragState.pointerId = e.pointerId
  dragState.startX = e.clientX
  dragState.startY = e.clientY
  dragState.startLeft = wrapEl.value.scrollLeft
  dragState.startTop = wrapEl.value.scrollTop
}

function onPointerMove(e: PointerEvent) {
  const wrap = wrapEl.value
  if (!dragState.active || !wrap) return
  const dx = e.clientX - dragState.startX
  const dy = e.clientY - dragState.startY
  if (!dragging.value && (Math.abs(dx) > 4 || Math.abs(dy) > 4)) {
    dragging.value = true
    hover.value = null
    try {
      wrap.setPointerCapture(dragState.pointerId)
    } catch {
      /* pointer may be gone */
    }
  }
  if (dragging.value) {
    wrap.scrollLeft = dragState.startLeft - dx
    wrap.scrollTop = dragState.startTop - dy
  }
}

function onPointerUp() {
  if (dragging.value) {
    suppressClick = true
    window.setTimeout(() => {
      suppressClick = false
    }, 80)
  }
  dragState.active = false
  dragging.value = false
}

onMounted(async () => {
  await nextTick()
  const wrap = wrapEl.value
  if (!wrap) return
  // Land with today at the left third of the viewport, like Linear.
  wrap.scrollLeft = (todayPct.value / 100) * wrap.scrollWidth - wrap.clientWidth * 0.3
})

// ── Time geometry ─────────────────────────────────────────
const months = computed(() => {
  const out: { key: string; label: string; year: string; widthPct: number; showYear: boolean; mIdx: number }[] = []
  const cur = new Date(rangeStart.value)
  let first = true
  while (cur < rangeEnd.value) {
    const next = new Date(cur.getFullYear(), cur.getMonth() + 1, 1)
    const days = (Math.min(next.getTime(), rangeEnd.value.getTime()) - cur.getTime()) / DAY
    out.push({
      key: `${cur.getFullYear()}-${cur.getMonth()}`,
      label: cur.toLocaleDateString('en-US', { month: 'short' }),
      year: String(cur.getFullYear()),
      widthPct: (days / totalDays.value) * 100,
      showYear: first || cur.getMonth() === 0,
      mIdx: cur.getMonth(),
    })
    first = false
    cur.setMonth(cur.getMonth() + 1)
  }
  return out
})

// Thin out month labels when months get narrow (small screens / zoomed out):
// every month → quarter starts → January only.
const monthLabelStep = computed(() => {
  const monthPx = 30.4 * (canvasW.value / visibleDays.value)
  if (monthPx >= 48) return 1
  if (monthPx * 3 >= 48) return 3
  return 12
})

const weeks = computed(() => {
  const out: { key: string; leftPct: number; day: number }[] = []
  const cur = new Date(rangeStart.value)
  // advance to the first Monday
  while (cur.getDay() !== 1) cur.setDate(cur.getDate() + 1)
  while (cur < rangeEnd.value) {
    out.push({
      key: cur.toISOString().slice(0, 10),
      leftPct: ((cur.getTime() - rangeStart.value.getTime()) / DAY / totalDays.value) * 100,
      day: cur.getDate(),
    })
    cur.setDate(cur.getDate() + 7)
  }
  return out
})

const quarters = computed(() => {
  const out: { key: string; leftPct: number; widthPct: number; shaded: boolean }[] = []
  const cur = new Date(rangeStart.value)
  cur.setMonth(Math.floor(cur.getMonth() / 3) * 3, 1)
  let i = 0
  while (cur < rangeEnd.value) {
    const next = new Date(cur.getFullYear(), cur.getMonth() + 3, 1)
    const s = Math.max(cur.getTime(), rangeStart.value.getTime())
    const e = Math.min(next.getTime(), rangeEnd.value.getTime())
    out.push({
      key: `q${cur.getFullYear()}-${cur.getMonth()}`,
      leftPct: ((s - rangeStart.value.getTime()) / DAY / totalDays.value) * 100,
      widthPct: ((e - s) / DAY / totalDays.value) * 100,
      shaded: i % 2 === 1,
    })
    i++
    cur.setMonth(cur.getMonth() + 3)
  }
  return out
})

function pctFor(dateStr: string): number {
  return ((toDate(dateStr).getTime() - rangeStart.value.getTime()) / DAY / totalDays.value) * 100
}

// Cursor date line (Linear shows the exact date under the pointer)
const cursor = ref<{ pct: number; label: string } | null>(null)

function onCanvasMove(e: MouseEvent) {
  const wrap = wrapEl.value
  if (!wrap || dragging.value) {
    cursor.value = null
    return
  }
  const rect = wrap.getBoundingClientRect()
  const frac = (wrap.scrollLeft + (e.clientX - rect.left)) / wrap.scrollWidth
  if (frac < 0 || frac > 1) {
    cursor.value = null
    return
  }
  const d = new Date(rangeStart.value.getTime() + frac * totalDays.value * DAY)
  cursor.value = {
    pct: frac * 100,
    label: d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }).toUpperCase(),
  }
}

function onCanvasLeave() {
  cursor.value = null
}

function fmtProgress(epic: Epic): string {
  if (!epic.progress) return ''
  const pct = Math.round(epic.progress.pct * 100)
  return epic.progress.note ? `${pct}% — ${epic.progress.note}` : `${pct}%`
}

function fmtMilestoneDate(s: string): string {
  return toDate(s).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

// Dependency connectors (drawn when an epic is selected, Linear-style)
const bodyEl = ref<HTMLElement | null>(null)
const depLines = ref<string[]>([])

function updateDepLines() {
  const body = bodyEl.value
  const sel = selected.value
  depLines.value = []
  if (!body || !sel?.dependsOn?.length) return
  const bodyRect = body.getBoundingClientRect()
  const to = body.querySelector(`[data-epic-id="${sel.id}"]`)
  if (!to) return
  const tr = to.getBoundingClientRect()
  const x2 = tr.left - bodyRect.left
  const y2 = tr.top - bodyRect.top + tr.height / 2
  for (const depId of sel.dependsOn) {
    const from = body.querySelector(`[data-epic-id="${depId}"]`)
    if (!from) continue
    const fr = from.getBoundingClientRect()
    const x1 = fr.right - bodyRect.left
    const y1 = fr.top - bodyRect.top + fr.height / 2
    depLines.value.push(`M ${x1} ${y1} C ${x1 + 48} ${y1}, ${x2 - 48} ${y2}, ${x2} ${y2}`)
  }
}

function barStyle(epic: Epic) {
  const left = pctFor(epic.start)
  const width = Math.max(pctFor(epic.end) - left, 0.1)
  return { left: `${left}%`, width: `${width}%` }
}

const todayPct = computed(() => pctFor(TODAY))
const todayLabel = toDate(TODAY)
  .toLocaleDateString('en-US', { day: 'numeric', month: 'short' })
  .toUpperCase()

// ── Filters, selection, hover ─────────────────────────────
type FilterKey = 'all' | 'done' | 'in-progress' | 'planned' | 'proposed'
const filter = ref<FilterKey>('all')
const filters: { key: FilterKey; label: string }[] = [
  { key: 'all', label: 'Everything' },
  { key: 'done', label: 'Shipped' },
  { key: 'in-progress', label: 'In progress' },
  { key: 'planned', label: 'Roadmap' },
]

// Pack non-overlapping epics onto shared rows. Epics with the same `row` key
// (a workstream: shipped work + the roadmap items that extend it) are forced
// onto one line; the rest pack pixel-aware at the current zoom so labels and
// milestone captions don't collide with row-mates.
const visibleLanes = computed(() => {
  const ppd = canvasW.value / visibleDays.value
  const startMs = rangeStart.value.getTime()
  return lanes
    .map((lane) => {
      const list = epics
        .filter((e) => e.lane === lane.id)
        .filter((e) => filter.value === 'all' || e.status === filter.value)
        .sort((a, b) => a.start.localeCompare(b.start))
      const rows: { epics: Epic[]; end: number; key?: string }[] = []
      const keyed = new Map<string, { epics: Epic[]; end: number; key?: string }>()
      for (const e of list) {
        const sPx = ((toDate(e.start).getTime() - startMs) / DAY) * ppd
        const ePx = ((toDate(e.end).getTime() - startMs) / DAY) * ppd
        const labelPx = 28 + (e.name.length + epicMeta(e).length) * 6.6
        const occEnd = Math.max(ePx + (e.milestones?.length ? 70 : 0), sPx + labelPx) + 32
        if (e.row) {
          const kr = keyed.get(e.row)
          if (kr) {
            kr.epics.push(e)
            kr.end = Math.max(kr.end, occEnd)
          } else {
            const row = { epics: [e], end: occEnd, key: e.row }
            keyed.set(e.row, row)
            rows.push(row)
          }
        } else {
          const row = rows.find((r) => !r.key && sPx >= r.end)
          if (row) {
            row.epics.push(e)
            row.end = occEnd
          } else {
            rows.push({ epics: [e], end: occEnd })
          }
        }
      }
      return { lane, rows: rows.map((r) => r.epics), count: list.length }
    })
    .filter((g) => g.count > 0)
})

const selected = ref<Epic | null>(null)

function select(epic: Epic) {
  if (suppressClick) return
  selected.value = selected.value?.id === epic.id ? null : epic
}

const hover = ref<{ epic: Epic; x: number; y: number } | null>(null)

function onBarMove(e: MouseEvent, epic: Epic) {
  if (dragging.value || isMobile.value) return
  hover.value = { epic, x: e.clientX, y: e.clientY }
}

function onBarLeave() {
  hover.value = null
}

function epicName(id: string): string {
  return epics.find((e) => e.id === id)?.name ?? id
}

function epicMeta(epic: Epic): string {
  if (epic.commits) return `${epic.commits} commits`
  if (epic.weeks) return `${epic.weeks} wks`
  return ''
}

function appDetail(a: { name: string; weeks?: number; commits?: number }): string {
  if (a.weeks) return `${a.name} — ${a.weeks} wks`
  if (a.commits) return `${a.name} — ${a.commits} commits`
  return a.name
}

function fmtDate(s: string): string {
  return toDate(s).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
}

function fmtRange(epic: Epic): string {
  const s = toDate(epic.start).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  const e = toDate(epic.end).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  return `${s} – ${e}`
}

function fmtMoney(n: number): string {
  return `$${n.toLocaleString('en-US')}`
}

function fmtTokens(m: number): string {
  return m >= 1000 ? `${(m / 1000).toFixed(1)}B` : `${m}M`
}

const statusLabels: Record<Epic['status'], string> = {
  done: 'Shipped',
  'in-progress': 'In progress',
  planned: 'Planned',
  proposed: 'Planned',
}

// Budget scenario toggle: 100% Fable 5 vs hybrid (routine work on
// Max-plan-covered Opus, Fable reserved for the hardest work).
const hybrid = (meta.budget as any).hybrid
const budgetMode = ref<'fable' | 'hybrid'>('fable')

function epicCostUsd(epic: Epic): number {
  if (!epic.tokens) return 0
  return budgetMode.value === 'hybrid'
    ? Math.round(epic.tokens.extraCostUsd * hybrid.fableShare)
    : epic.tokens.extraCostUsd
}

const monthlyBudgetStr = computed(() => {
  const v = budgetMode.value === 'hybrid' ? hybrid.recommendedMonthlyBudgetUsd : meta.budget.recommendedMonthlyBudgetUsd
  return `$${v.toLocaleString('en-US')}/mo`
})

const roadmapBudgetStr = computed(() => {
  const v = budgetMode.value === 'hybrid' ? hybrid.fullRoadmapCostUsd : meta.budget.fullRoadmapCostUsd
  return `$${(v / 1000).toFixed(1)}k`
})

// Mobile: the two budget tiles collapse into one tappable KPI that opens
// this sheet (detail + mode switch); the filter chips collapse into a menu.
const budgetSheet = ref(false)
const filterMenu = ref(false)

const kpis = computed(() => [
  { value: meta.velocity.totalCommits.toLocaleString('en-US'), label: 'commits in 8 months', budget: false },
  { value: String((meta.velocity as any).productEpics ?? meta.velocity.completedEpics), label: 'product pillars shipped', budget: false },
  { value: '1 dev + AI', label: 'entire team', budget: false },
  {
    value: monthlyBudgetStr.value,
    label: budgetMode.value === 'hybrid' ? 'AI token budget (Fable + Opus)' : 'AI token budget (100% Fable 5)',
    budget: true,
  },
  {
    value: roadmapBudgetStr.value,
    label: `full-roadmap token budget, ${meta.budget.fullRoadmapWorkWeeks} wks`,
    budget: true,
  },
])

const filterLabel = computed(() => filters.find((f) => f.key === filter.value)?.label ?? 'Everything')

watch([selected, visibleDays, filter], () => nextTick(updateDepLines))
</script>

<template>
  <div class="InvestorTimeline">
    <div class="InvestorTimeline__shell">
    <header class="InvestorTimeline__header">
      <div class="InvestorTimeline__headText">
        <p class="InvestorTimeline__eyebrow">MakeReady &middot; Confidential &middot; Generated {{ fmtDate(meta.generated) }} from git history</p>
        <h1 class="InvestorTimeline__title">Product Development Timeline</h1>
        <p class="InvestorTimeline__subtitle">
          Everything shipped since October 2025 — measured from {{ meta.velocity.totalCommits.toLocaleString('en-US') }} commits —
          and the roadmap through early 2028. Click any bar for the full story.
        </p>
      </div>
      <div class="InvestorTimeline__headRight">
        <div class="InvestorTimeline__kpis">
          <template v-for="kpi in kpis" :key="kpi.label">
            <div v-if="!kpi.budget || !isMobile" class="InvestorTimeline__kpi">
              <span class="InvestorTimeline__kpiValue">{{ kpi.value }}</span>
              <span class="InvestorTimeline__kpiLabel">{{ kpi.label }}</span>
            </div>
          </template>
          <button
            v-if="isMobile"
            class="InvestorTimeline__kpi InvestorTimeline__kpi--tap"
            type="button"
            @click="toggleBudgetSheet"
          >
            <span class="InvestorTimeline__kpiValue">{{ monthlyBudgetStr }}</span>
            <span class="InvestorTimeline__kpiLabel">AI tokens · {{ budgetMode === 'hybrid' ? 'hybrid' : 'Fable 5' }} ▾</span>
          </button>
        </div>
        <button
          v-if="!isMobile"
          class="InvestorTimeline__budgetToggle"
          type="button"
          role="switch"
          :aria-checked="budgetMode === 'hybrid'"
          @click="budgetMode = budgetMode === 'hybrid' ? 'fable' : 'hybrid'"
        >
          <span
            class="InvestorTimeline__budgetOption"
            :class="{ 'InvestorTimeline__budgetOption--active': budgetMode === 'fable' }"
          >Fable 5 only</span>
          <span class="InvestorTimeline__budgetTrack" :class="{ 'InvestorTimeline__budgetTrack--right': budgetMode === 'hybrid' }">
            <span class="InvestorTimeline__budgetKnob"></span>
          </span>
          <span
            class="InvestorTimeline__budgetOption"
            :class="{ 'InvestorTimeline__budgetOption--active': budgetMode === 'hybrid' }"
          >Hybrid Fable &amp; Opus</span>
        </button>
        <div v-if="budgetSheet && isMobile" class="InvestorTimeline__budgetSheet">
          <div class="InvestorTimeline__budgetSheetRow">
            <strong>{{ monthlyBudgetStr }}</strong>
            <span>monthly AI token budget</span>
          </div>
          <div class="InvestorTimeline__budgetSheetRow">
            <strong>{{ roadmapBudgetStr }}</strong>
            <span>full roadmap, {{ meta.budget.fullRoadmapWorkWeeks }} wks</span>
          </div>
          <div class="InvestorTimeline__budgetSheetModes">
            <button
              type="button"
              :class="{ 'is-active': budgetMode === 'fable' }"
              @click="budgetMode = 'fable'"
            >Fable 5 only</button>
            <button
              type="button"
              :class="{ 'is-active': budgetMode === 'hybrid' }"
              @click="budgetMode = 'hybrid'"
            >Hybrid Fable &amp; Opus</button>
          </div>
          <p>Hybrid routes routine work to Max-plan-covered Opus (~69% of tokens); Fable 5 covers the rest plus the $200/mo plan.</p>
        </div>
      </div>
    </header>

    <div class="InvestorTimeline__controls">
      <template v-if="!isMobile">
        <button
          v-for="f in filters"
          :key="f.key"
          class="InvestorTimeline__chip"
          :class="{ 'InvestorTimeline__chip--active': filter === f.key }"
          type="button"
          @click="filter = f.key"
        >
          {{ f.label }}
        </button>
      </template>
      <div v-else class="InvestorTimeline__filterWrap">
        <button class="InvestorTimeline__chip InvestorTimeline__chip--active" type="button" @click="toggleFilterMenu">
          {{ filterLabel }} ▾
        </button>
        <div v-if="filterMenu" class="InvestorTimeline__filterMenu">
          <button
            v-for="f in filters"
            :key="f.key"
            type="button"
            :class="{ 'is-active': filter === f.key }"
            @click="filter = f.key; filterMenu = false"
          >
            {{ f.label }}
          </button>
        </div>
      </div>
      <button class="InvestorTimeline__chip InvestorTimeline__chip--today" type="button" @click="scrollToToday">Today</button>
      <span class="InvestorTimeline__hint">Scroll to zoom &middot; drag to pan &middot; T today &middot; M/Q/Y zoom &middot; 0 reset</span>
      <div class="InvestorTimeline__legend">
        <span class="InvestorTimeline__legendItem InvestorTimeline__legendItem--done">Shipped</span>
        <span class="InvestorTimeline__legendItem InvestorTimeline__legendItem--progress">In progress</span>
        <span class="InvestorTimeline__legendItem InvestorTimeline__legendItem--planned">Planned</span>
      </div>
    </div>

    <div class="InvestorTimeline__layout">
      <div
        ref="wrapEl"
        class="InvestorTimeline__ganttWrap"
        :class="{ 'InvestorTimeline__ganttWrap--dragging': dragging }"
        @wheel="onWheel"
        @pointerdown="onPointerDown"
        @pointermove="onPointerMove"
        @pointerup="onPointerUp"
        @pointercancel="onPointerUp"
        @mousemove="onCanvasMove"
        @mouseleave="onCanvasLeave"
        @click="onCanvasClick"
      >
        <div class="InvestorTimeline__gantt" :style="{ width: `${contentWidthPct}%` }">
          <div class="InvestorTimeline__axis">
            <div
              v-for="m in months"
              :key="m.key"
              class="InvestorTimeline__month"
              :style="{ width: `${m.widthPct}%` }"
            >
              <span v-if="m.mIdx % monthLabelStep === 0" class="InvestorTimeline__monthLabel">
                {{ m.label }}<em v-if="m.showYear">&nbsp;{{ m.year }}</em>
              </span>
            </div>
            <template v-if="showWeeks">
              <span
                v-for="w in weeks"
                :key="w.key"
                class="InvestorTimeline__weekTick"
                :style="{ left: `${w.leftPct}%` }"
              >{{ w.day }}</span>
            </template>
            <span
              v-if="cursor"
              class="InvestorTimeline__cursorDate"
              :style="{ left: `${cursor.pct}%` }"
            >{{ cursor.label }}</span>
            <span class="InvestorTimeline__todayPill" :style="{ left: `${todayPct}%` }">{{ todayLabel }}</span>
          </div>

          <div ref="bodyEl" class="InvestorTimeline__body">
            <template v-for="q in quarters" :key="q.key">
              <span
                v-if="q.shaded"
                class="InvestorTimeline__quarter"
                :style="{ left: `${q.leftPct}%`, width: `${q.widthPct}%` }"
              ></span>
            </template>
            <div class="InvestorTimeline__grid">
              <span v-for="m in months" :key="m.key" :style="{ width: `${m.widthPct}%` }"></span>
            </div>
            <template v-if="showWeeks">
              <span
                v-for="w in weeks"
                :key="`g-${w.key}`"
                class="InvestorTimeline__weekLine"
                :style="{ left: `${w.leftPct}%` }"
              ></span>
            </template>
            <div class="InvestorTimeline__todayLine" :style="{ left: `${todayPct}%` }"></div>
            <div v-if="cursor" class="InvestorTimeline__cursorLine" :style="{ left: `${cursor.pct}%` }"></div>

            <template v-for="group in visibleLanes" :key="group.lane.id">
              <div v-if="visibleLanes.length > 1" class="InvestorTimeline__laneHeader">
                {{ group.lane.name }}
                <span class="InvestorTimeline__laneCount">{{ group.count }}</span>
              </div>
              <div v-for="(row, ri) in group.rows" :key="`${group.lane.id}-${ri}`" class="InvestorTimeline__row">
                <template v-for="epic in row" :key="epic.id">
                  <div class="InvestorTimeline__labelTrack" :style="barStyle(epic)">
                    <div class="InvestorTimeline__rowLabel" @click="select(epic)">
                      <span class="InvestorTimeline__dot" :class="`InvestorTimeline__dot--${epic.status}`"></span>
                      <span class="InvestorTimeline__rowName">{{ epic.name }}</span>
                      <span class="InvestorTimeline__rowMeta">{{ epicMeta(epic) }}</span>
                    </div>
                  </div>
                  <button
                    class="InvestorTimeline__bar"
                    :class="[`InvestorTimeline__bar--${epic.status}`, { 'InvestorTimeline__bar--selected': selected?.id === epic.id }]"
                    :style="barStyle(epic)"
                    type="button"
                    :data-epic-id="epic.id"
                    :aria-label="`${epic.name}: ${fmtDate(epic.start)} to ${fmtDate(epic.end)}`"
                    @click="select(epic)"
                    @mousemove="onBarMove($event, epic)"
                    @mouseleave="onBarLeave"
                  >
                    <span
                      v-if="epic.progress && epic.status === 'in-progress'"
                      class="InvestorTimeline__barProgress"
                      :style="{ width: `${epic.progress.pct * 100}%` }"
                    ></span>
                  </button>
                  <template v-for="ms in epic.milestones || []" :key="`${epic.id}-${ms.date}`">
                    <span
                      class="InvestorTimeline__milestone"
                      :style="{ left: `${pctFor(ms.date)}%` }"
                      :title="`${ms.label} · ${fmtMilestoneDate(ms.date)}`"
                    ></span>
                    <span
                      v-if="showWeeks"
                      class="InvestorTimeline__milestoneLabel"
                      :style="{ left: `${pctFor(ms.date)}%` }"
                    >{{ ms.label }}</span>
                  </template>
                </template>
              </div>
            </template>

            <svg v-if="depLines.length" class="InvestorTimeline__deps">
              <path v-for="(d, i) in depLines" :key="i" :d="d" />
            </svg>
          </div>
        </div>
      </div>

      <aside v-if="selected" class="InvestorTimeline__detail">
        <button class="InvestorTimeline__detailClose" type="button" @click="selected = null">&times;</button>
        <span class="InvestorTimeline__detailStatus" :class="`InvestorTimeline__detailStatus--${selected.status}`">
          {{ statusLabels[selected.status] }}
        </span>
        <h2 class="InvestorTimeline__detailTitle">{{ selected.name }}</h2>
        <p class="InvestorTimeline__detailDates">
          {{ fmtDate(selected.start) }} &rarr; {{ fmtDate(selected.end) }}
          <template v-if="selected.commits"> &middot; {{ selected.commits }} commits</template>
          <template v-else-if="selected.weeks"> &middot; est. {{ selected.weeks }} weeks</template>
        </p>
        <p v-if="selected.progress" class="InvestorTimeline__detailDates">{{ fmtProgress(selected) }}</p>
        <p class="InvestorTimeline__detailDesc">{{ selected.description }}</p>

        <template v-if="selected.phases?.length">
          <h3 class="InvestorTimeline__detailHeading">{{ selected.status === 'done' ? 'What shipped inside' : 'Phases' }}</h3>
          <div v-for="p in selected.phases" :key="p.name" class="InvestorTimeline__phase">
            <div class="InvestorTimeline__phaseHead">
              <strong>{{ p.name }}</strong>
              <span v-if="p.meta">{{ p.meta }}</span>
            </div>
            <p>{{ p.summary }}</p>
          </div>
        </template>

        <template v-if="selected.milestones?.length">
          <h3 class="InvestorTimeline__detailHeading">Milestones</h3>
          <div v-for="ms in selected.milestones" :key="ms.date" class="InvestorTimeline__detailMilestone">
            <span class="InvestorTimeline__detailDiamond"></span>
            <span>{{ ms.label }} — {{ fmtMilestoneDate(ms.date) }}</span>
          </div>
        </template>

        <template v-if="selected.deliverables?.length">
          <h3 class="InvestorTimeline__detailHeading">{{ selected.status === 'done' ? 'Delivered' : 'Scope' }}</h3>
          <ul class="InvestorTimeline__detailList">
            <li v-for="d in selected.deliverables" :key="d">{{ d }}</li>
          </ul>
        </template>

        <template v-if="selected.apps?.length">
          <h3 class="InvestorTimeline__detailHeading">Where it gets built</h3>
          <ul class="InvestorTimeline__detailList">
            <li v-for="a in selected.apps" :key="a.name">{{ appDetail(a) }}</li>
          </ul>
        </template>

        <template v-if="selected.dependsOn?.length">
          <h3 class="InvestorTimeline__detailHeading">Depends on</h3>
          <p class="InvestorTimeline__detailText">
            {{ selected.dependsOn.map(epicName).join(', ') }}
          </p>
        </template>

        <template v-if="selected.userStories?.length">
          <h3 class="InvestorTimeline__detailHeading">Original user stories served</h3>
          <p class="InvestorTimeline__detailText">{{ selected.userStories.join(' · ') }}</p>
        </template>

        <template v-if="selected.tokens">
          <h3 class="InvestorTimeline__detailHeading">AI development token budget</h3>
          <div class="InvestorTimeline__tokenGrid">
            <div>
              <strong>{{ fmtTokens(selected.tokens.processedM) }}</strong>
              <span>input tokens processed</span>
            </div>
            <div>
              <strong>{{ fmtTokens(selected.tokens.outputM) }}</strong>
              <span>output tokens</span>
            </div>
            <div>
              <strong>{{ fmtMoney(epicCostUsd(selected)) }}</strong>
              <span>{{ budgetMode === 'hybrid' ? 'extra tokens (hybrid)' : 'extra tokens (100% Fable 5)' }}</span>
            </div>
          </div>
          <p v-if="budgetMode === 'hybrid'" class="InvestorTimeline__detailText">
            Hybrid: routine work runs on Opus 4.8 under the $200/mo Max plan (~69% of tokens); Fable 5 covers the rest.
          </p>
        </template>
      </aside>
    </div>
    </div>

    <Teleport to="body">
      <div
        v-if="hover"
        class="InvestorTimelineTooltip"
        :style="{ left: `${Math.min(hover.x + 14, 1200)}px`, top: `${hover.y + 16}px` }"
      >
        <div class="InvestorTimelineTooltip__name">
          <span class="InvestorTimelineTooltip__dot" :class="`InvestorTimelineTooltip__dot--${hover.epic.status}`"></span>
          {{ hover.epic.name }}
        </div>
        <div class="InvestorTimelineTooltip__meta">
          {{ fmtRange(hover.epic) }}<template v-if="epicMeta(hover.epic)"> &middot; {{ epicMeta(hover.epic) }}</template>
        </div>
        <div v-if="hover.epic.progress" class="InvestorTimelineTooltip__meta">{{ fmtProgress(hover.epic) }}</div>
      </div>
    </Teleport>

  </div>
</template>
