<script setup lang="ts">
// LineChartTwin — web twin of the iOS `LineChart` (SwiftUI Swift Charts
// `LineMark` / `AreaMark`).
//
// Renders one or more time-series trend lines as an inline SVG so it can be
// compared apples-to-apples against the iPhone build in the Compare tool. Fully
// prop driven; renders every comparison variant (gradient line + area fill,
// solid single line, multiple solid trends) from the same canonical data.
//
// ── Geometry (reverse-engineered from the pro-max iPhone snapshots) ──
// The iOS `LineChart` is `.frame(height: 120)` and the capture harness wraps it
// in a 16pt gutter, so the component's own box is `contentWidth × 120` (pt→px
// 1:1, captured at 3×). Inside that box Swift Charts reserves a leading gutter
// for the y-axis value labels and a bottom strip for the x-axis labels, leaving
// the plot region. Measuring the three references gives a consistent mapping:
//   • domain MAX value sits at the very top (y ≈ 0), domain MIN at y ≈ 100,
//   • the first data point sits ~23px in (after the y-label gutter) and the last
//     touches the right edge,
//   • x-axis labels sit centred at y ≈ 111.
// The y-domain + tick selection mirror the iOS auto algorithm exactly; the line
// uses a monotone (Fritsch–Carlson) cubic spline to match Swift's `.monotone`.
//
// Colours arrive already resolved by the adapter (the iOS ViewRegistry remaps
// each fixture hex to a brand token — `#6c47ff`→brandPrimary, `#47d4ff`→
// accentBlue — and any unknown shade to brandPrimary), so this component renders
// the colours verbatim.
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

export interface LineChartDataPoint {
  date: string // "yyyy-MM-dd"
  value: number
}

export interface LineChartTrendLine {
  color: 'solid' | 'gradient'
  solidColor?: string
  gradientColors?: string[]
  gradientAngle?: number
  lineWidth?: number
  dataPoints: LineChartDataPoint[]
}

interface Props {
  trendLines: LineChartTrendLine[]
  timeScale?: 'hours' | 'days' | 'weeks' | 'months' | 'years'
  showArea?: boolean
  interpolationMethod?: 'linear' | 'monotone' | 'catmullRom'
}

const props = withDefaults(defineProps<Props>(), {
  timeScale: 'days',
  showArea: false,
  interpolationMethod: 'monotone',
})

// ── Plot geometry (px within the component's own box, height fixed at 120) ──
const HEIGHT = 120
const PLOT_LEFT = 23 // leading y-axis label gutter (measured)
const PLOT_TOP = 1 // domain-max value lands at the very top
const PLOT_BOTTOM = 100 // domain-min value; below this is the x-axis label strip
const X_LABEL_Y = 111 // x-axis label vertical centre (measured)
// Swift Charts anchors each x-axis label to the right of its raw value position
// by an amount that scales with the (per-scale) tick interval — measuring the
// three references gives these px nudges, which line the faint label row up with
// the iPhone snapshot. (Swift centres coarse date labels over their span rather
// than at the tick gridline; this reproduces that without modelling its calendar
// tick engine.)
const X_LABEL_OFFSETS: Record<string, number> = {
  hours: 20,
  days: 31,
  weeks: 24,
  months: 16,
  years: 58,
}

// Width is measured from the live container so the SVG maps 1:1 to CSS px on
// both the pro-max and se viewports (no viewBox distortion of stroke widths).
const rootEl = ref<HTMLElement | null>(null)
const width = ref(408) // pro-max content width (440 − 2×16) until measured
let ro: ResizeObserver | null = null
onMounted(() => {
  const measure = () => {
    if (rootEl.value) width.value = rootEl.value.clientWidth
  }
  measure()
  ro = new ResizeObserver(measure)
  if (rootEl.value) ro.observe(rootEl.value)
})
onBeforeUnmount(() => ro?.disconnect())

const plotRight = computed(() => width.value)

// ── Dates ──────────────────────────────────────────────────────────────────
function parseDate(s: string): number {
  // UTC midnight, matching the iOS ViewRegistry's POSIX/UTC date parser.
  const [y, m, d] = (s || '').split('-').map(Number)
  return Date.UTC(y || 1970, (m || 1) - 1, d || 1)
}

const allPoints = computed(() =>
  props.trendLines.flatMap((t) => t.dataPoints || [])
)

const minTs = computed(() =>
  allPoints.value.reduce(
    (m, p) => Math.min(m, parseDate(p.date)),
    Number.POSITIVE_INFINITY
  )
)
const maxTs = computed(() =>
  allPoints.value.reduce(
    (m, p) => Math.max(m, parseDate(p.date)),
    Number.NEGATIVE_INFINITY
  )
)

// ── Y domain + ticks (mirror iOS `yAxisDomain` + Swift auto marks) ───────────
const yDomain = computed(() => {
  const values = allPoints.value.map((p) => p.value || 0)
  const minV = values.length ? Math.min(...values) : 0
  const maxV = values.length ? Math.max(...values) : 100
  return { min: Math.floor(minV / 10) * 10, max: Math.ceil(maxV / 10) * 10 }
})

// Swift Charts "nice" step targeting ~5 intervals across the domain.
function niceStep(span: number): number {
  if (span <= 0) return 1
  const raw = span / 5
  const mag = Math.pow(10, Math.floor(Math.log10(raw)))
  const norm = raw / mag
  let mult: number
  if (norm <= 1) mult = 1
  else if (norm <= 2) mult = 2
  else if (norm <= 2.5) mult = 2.5
  else if (norm <= 5) mult = 5
  else mult = 10
  return mult * mag
}

// iOS formatYAxisValue: ≥1000 → "%.0fk"; integer → "%.0f"; else "%.1f".
function formatYValue(v: number): string {
  if (v >= 1000) return `${Math.round(v / 1000)}k`
  if (Number.isInteger(v)) return `${v}`
  return v.toFixed(1)
}

const yTicks = computed(() => {
  const { min, max } = yDomain.value
  const step = niceStep(max - min)
  const out: { value: number; y: number; label: string }[] = []
  // Multiples of step within [min, max] inclusive (matches Swift's marks).
  const start = Math.ceil(min / step) * step
  for (let v = start; v <= max + 1e-6; v += step) {
    out.push({ value: v, y: yForValue(v), label: formatYValue(v) })
  }
  return out
})

function yForValue(v: number): number {
  const { min, max } = yDomain.value
  const t = max > min ? (v - min) / (max - min) : 0
  return PLOT_BOTTOM - t * (PLOT_BOTTOM - PLOT_TOP)
}

function xForTs(ts: number): number {
  const t = maxTs.value > minTs.value ? (ts - minTs.value) / (maxTs.value - minTs.value) : 0
  return PLOT_LEFT + t * (plotRight.value - PLOT_LEFT)
}

// ── X-axis ticks (reverse-engineered per time scale to match Swift's auto
// calendar marks; only the three fixture scales are exercised) ───────────────
const DAY = 86400000

function utc(ts: number) {
  const d = new Date(ts)
  return { y: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate() }
}

function fmtWeekday(ts: number) {
  return new Date(ts).toLocaleDateString('en-US', { weekday: 'short', timeZone: 'UTC' })
}
function fmtMonth(ts: number) {
  return new Date(ts).toLocaleDateString('en-US', { month: 'short', timeZone: 'UTC' })
}
function fmtYear(ts: number) {
  return new Date(ts).toLocaleDateString('en-US', { year: 'numeric', timeZone: 'UTC' })
}

const xTicks = computed(() => {
  const lo = minTs.value
  const hi = maxTs.value
  if (!isFinite(lo) || !isFinite(hi) || hi <= lo) return []
  const ticks: { ts: number; label: string }[] = []
  const inside = (ts: number) => ts > lo && ts < hi

  if (props.timeScale === 'days') {
    // Every 2nd day starting one day in (→ Wed, Fri, Sun for a Tue–Mon week).
    for (let ts = lo + DAY; ts < hi; ts += 2 * DAY) {
      if (inside(ts)) ticks.push({ ts, label: fmtWeekday(ts) })
    }
  } else if (props.timeScale === 'months') {
    // First of each month whose 1-indexed month is a multiple of 3 (Mar/Jun/Sep…).
    for (let ts = monthFloor(lo); ts <= hi; ts = monthAdd(ts, 1)) {
      const { m } = utc(ts)
      if (m % 3 === 0 && inside(ts)) ticks.push({ ts, label: fmtMonth(ts) })
    }
  } else if (props.timeScale === 'years') {
    // Semi-annual marks (Apr/Oct) — Swift's auto choice for a ~2-year span.
    for (let ts = monthFloor(lo); ts <= hi; ts = monthAdd(ts, 1)) {
      const { m } = utc(ts)
      if (m % 6 === 4 && inside(ts)) ticks.push({ ts, label: fmtYear(ts) })
    }
  } else if (props.timeScale === 'weeks') {
    for (let ts = lo + 7 * DAY; ts < hi; ts += 7 * DAY) {
      const week = isoWeek(ts)
      if (inside(ts)) ticks.push({ ts, label: `W${week}` })
    }
  }
  const offset = X_LABEL_OFFSETS[props.timeScale] ?? 22
  return ticks.map((t) => ({ label: t.label, x: xForTs(t.ts) + offset }))
})

function monthFloor(ts: number): number {
  const { y, m } = utc(ts)
  return Date.UTC(y, m - 1, 1)
}
function monthAdd(ts: number, n: number): number {
  const { y, m } = utc(ts)
  return Date.UTC(y, m - 1 + n, 1)
}
function isoWeek(ts: number): number {
  const d = new Date(ts)
  const day = (d.getUTCDay() + 6) % 7
  d.setUTCDate(d.getUTCDate() - day + 3)
  const firstThursday = Date.UTC(d.getUTCFullYear(), 0, 4)
  return 1 + Math.round((d.getTime() - firstThursday) / (7 * DAY))
}

// ── Monotone cubic spline (Fritsch–Carlson) → SVG path ───────────────────────
function buildPath(pts: { x: number; y: number }[], method: string): string {
  if (pts.length === 0) return ''
  if (pts.length === 1) return `M ${pts[0].x} ${pts[0].y}`
  if (method === 'linear' || pts.length === 2) {
    return 'M ' + pts.map((p) => `${p.x} ${p.y}`).join(' L ')
  }
  const n = pts.length
  const dx: number[] = []
  const dy: number[] = []
  const slope: number[] = []
  for (let i = 0; i < n - 1; i++) {
    dx[i] = pts[i + 1].x - pts[i].x
    dy[i] = pts[i + 1].y - pts[i].y
    slope[i] = dx[i] !== 0 ? dy[i] / dx[i] : 0
  }
  const m: number[] = new Array(n)
  m[0] = slope[0]
  m[n - 1] = slope[n - 2]
  for (let i = 1; i < n - 1; i++) {
    if (slope[i - 1] * slope[i] <= 0) m[i] = 0
    else m[i] = (slope[i - 1] + slope[i]) / 2
  }
  // Fritsch–Carlson monotonicity clamp.
  for (let i = 0; i < n - 1; i++) {
    if (slope[i] === 0) {
      m[i] = 0
      m[i + 1] = 0
      continue
    }
    const a = m[i] / slope[i]
    const b = m[i + 1] / slope[i]
    const s = a * a + b * b
    if (s > 9) {
      const tau = 3 / Math.sqrt(s)
      m[i] = tau * a * slope[i]
      m[i + 1] = tau * b * slope[i]
    }
  }
  let d = `M ${pts[0].x} ${pts[0].y}`
  for (let i = 0; i < n - 1; i++) {
    const c1x = pts[i].x + dx[i] / 3
    const c1y = pts[i].y + (m[i] * dx[i]) / 3
    const c2x = pts[i + 1].x - dx[i] / 3
    const c2y = pts[i + 1].y - (m[i + 1] * dx[i]) / 3
    d += ` C ${c1x} ${c1y} ${c2x} ${c2y} ${pts[i + 1].x} ${pts[i + 1].y}`
  }
  return d
}

// Swift's `angleToPoints`: angle (deg) → start/end unit points over the bbox.
function gradientCoords(angle: number) {
  const rad = (angle * Math.PI) / 180
  const cx = Math.cos(rad)
  const cy = Math.sin(rad)
  return {
    x1: 0.5 - cx / 2,
    y1: 0.5 - cy / 2,
    x2: 0.5 + cx / 2,
    y2: 0.5 + cy / 2,
  }
}

function trendPoints(tl: LineChartTrendLine) {
  return (tl.dataPoints || [])
    .map((p) => ({ x: xForTs(parseDate(p.date)), y: yForValue(p.value || 0) }))
    .sort((a, b) => a.x - b.x)
}

function renderLine(tl: LineChartTrendLine, i: number, linePath: string, areaPath: string) {
  const isGradient = tl.color === 'gradient'
  const gColors = tl.gradientColors && tl.gradientColors.length
    ? tl.gradientColors
    : ['#6C47FF']
  return {
    linePath,
    areaPath,
    lineWidth: tl.lineWidth ?? 2,
    isGradient,
    stroke: isGradient ? `url(#lc-stroke-${i})` : tl.solidColor || '#6C47FF',
    gColors,
    gCoords: gradientCoords(tl.gradientAngle ?? 90),
    areaColor: gColors[0],
    strokeId: `lc-stroke-${i}`,
    areaId: `lc-area-${i}`,
  }
}

const lines = computed(() => {
  const tls = props.trendLines || []

  // ── iPhone parity: multi-trend merge ──
  // The iOS LineChart draws its trend lines with `ForEach … LineMark` but never
  // assigns a Swift Charts series id (no `by:`), so Swift Charts collapses ALL
  // trend lines into a SINGLE series, strokes the whole thing with the FIRST
  // trend line's colour, and connects the marks in array order. That last step
  // draws a straight connector from one trend line's final point back to the
  // next trend line's first point — the diagonal that crosses the curves in the
  // reference snapshot. We reproduce it exactly: one path = each trend line's
  // own monotone curve, joined to the next by a straight segment, all stroked in
  // the first trend line's colour.
  if (tls.length > 1) {
    // Concatenate every trend line's (date-sorted) points in array order and run
    // ONE monotone spline through the lot — exactly what Swift Charts does with a
    // single merged series. The x-sequence runs forward within each trend line
    // then jumps back at each boundary, so the spline naturally draws the curved
    // (sagging) connector the reference shows.
    const merged = tls.flatMap((tl) => trendPoints(tl))
    const d = buildPath(merged, props.interpolationMethod)
    return [renderLine(tls[0], 0, d, '')]
  }

  return tls.map((tl, i) => {
    const pts = trendPoints(tl)
    const linePath = buildPath(pts, props.interpolationMethod)
    const last = pts[pts.length - 1]
    const first = pts[0]
    const areaPath =
      pts.length && props.showArea
        ? `${linePath} L ${last.x} ${PLOT_BOTTOM} L ${first.x} ${PLOT_BOTTOM} Z`
        : ''
    return renderLine(tl, i, linePath, areaPath)
  })
})
</script>

<template>
  <div ref="rootEl" class="LineChartTwin">
    <svg
      class="LineChartTwin__svg"
      :width="width"
      :height="HEIGHT"
      :viewBox="`0 0 ${width} ${HEIGHT}`"
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      <defs>
        <template v-for="(ln, i) in lines" :key="`def-${i}`">
          <linearGradient
            v-if="ln.isGradient"
            :id="ln.strokeId"
            :x1="ln.gCoords.x1"
            :y1="ln.gCoords.y1"
            :x2="ln.gCoords.x2"
            :y2="ln.gCoords.y2"
          >
            <stop
              v-for="(c, ci) in ln.gColors"
              :key="ci"
              :offset="ln.gColors.length > 1 ? ci / (ln.gColors.length - 1) : 0"
              :stop-color="c"
            />
          </linearGradient>
          <linearGradient
            v-if="ln.areaPath"
            :id="ln.areaId"
            x1="0"
            y1="0"
            x2="0"
            y2="1"
          >
            <stop offset="0" :stop-color="ln.areaColor" stop-opacity="0.3" />
            <stop offset="1" :stop-color="ln.areaColor" stop-opacity="0" />
          </linearGradient>
        </template>
      </defs>

      <!-- Area fills first so the lines sit on top. -->
      <path
        v-for="(ln, i) in lines"
        v-show="ln.areaPath"
        :key="`area-${i}`"
        :d="ln.areaPath"
        :fill="`url(#${ln.areaId})`"
      />

      <path
        v-for="(ln, i) in lines"
        :key="`line-${i}`"
        :d="ln.linePath"
        fill="none"
        :stroke="ln.stroke"
        :stroke-width="ln.lineWidth"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>

    <!-- Y-axis value labels (leading), right-aligned against the plot gutter. -->
    <span
      v-for="(t, i) in yTicks"
      :key="`y-${i}`"
      class="LineChartTwin__ylabel"
      :style="{ top: `${t.y}px` }"
      >{{ t.label }}</span
    >

    <!-- X-axis labels (bottom). -->
    <span
      v-for="(t, i) in xTicks"
      :key="`x-${i}`"
      class="LineChartTwin__xlabel"
      :style="{ left: `${t.x}px`, top: `${X_LABEL_Y}px` }"
      >{{ t.label }}</span
    >
  </div>
</template>
