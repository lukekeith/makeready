<script setup lang="ts">
// HomeDashboard — capture-only web leader twin of the iPhone MainHome "Home"
// tab (Pages/Main/MainHome.swift). Capture-only, like group-home-leader; the
// production web analog is the admin SPA dashboard, left untouched.
//
// The whole screen is composed from EXISTING design-system twins — PageHeader
// (Home/Activity tabs), Kpi (the four stat cards), VerticalBarChart (Last 7
// Days), HeatMapChart (Activity Heatmap), NavBar (bottom tabs) — so this adds
// only the page chrome (KPI grid + section labels) and the SF-symbol KPI icons.
import PageHeader from '../page-header/page-header.vue'
import Kpi from '../kpi/kpi.vue'
import VerticalBarChart from '../vertical-bar-chart/vertical-bar-chart.vue'
import HeatMapChart from '../heat-map-chart/heat-map-chart.vue'
import NavBar from '../nav-bar/nav-bar.vue'

interface WeeklyPoint { label: string; value: number }
interface HeatPoint { day: number; hour: number; value: number }

interface Props {
  totalMembers?: number
  totalGroups?: number
  totalEnrolledLessons?: number
  totalStudies?: number
  weeklyActivity?: WeeklyPoint[]
  heatmap?: HeatPoint[]
}

const props = withDefaults(defineProps<Props>(), {
  totalMembers: 0,
  totalGroups: 0,
  totalEnrolledLessons: 0,
  totalStudies: 0,
  weeklyActivity: () => [],
  heatmap: () => [],
})

// SF-symbol KPI icons (OUTLINE variants — iOS passes person.2 / person.3 /
// book / text.book.closed, none of them .fill, tinted brandPrimary).
const PERSON_2 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="7.5" r="3.3"/><path d="M3 19.5c0-3.3 2.7-5.6 6-5.6s6 2.3 6 5.6"/><path d="M15.2 4.6a3.3 3.3 0 0 1 0 6"/><path d="M16.6 14.2c2.5.5 4.4 2.6 4.4 5.3"/></svg>'
const PERSON_3 =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="7.8" r="3"/><path d="M6.7 19c0-2.9 2.4-5 5.3-5s5.3 2.1 5.3 5"/><circle cx="4.6" cy="9.4" r="2.3"/><path d="M2 17.5c0-2 1.3-3.6 3.2-4"/><circle cx="19.4" cy="9.4" r="2.3"/><path d="M22 17.5c0-2-1.3-3.6-3.2-4"/></svg>'
const BOOK =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M12 6.6C10.5 5.4 8.4 4.8 6 4.8c-1.1 0-2.1.1-3 .4v13c.9-.3 1.9-.4 3-.4 2.4 0 4.5.6 6 1.8"/><path d="M12 6.6c1.5-1.2 3.6-1.8 6-1.8 1.1 0 2.1.1 3 .4v13c-.9-.3-1.9-.4-3-.4-2.4 0-4.5.6-6 1.8z"/></svg>'
const BOOK_CLOSED =
  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M6.5 3.5h10A1.5 1.5 0 0 1 18 5v15.5l-2-1.4-2 1.4-2-1.4-2 1.4-2-1.4-2 1.4V5A1.5 1.5 0 0 1 6.5 3.5z"/><path d="M8.5 8h7M8.5 11h7"/></svg>'

const KPI_ACCENT = '#6c47ff' // iOS Color.brandPrimary

const kpis = [
  { value: props.totalMembers, label: 'Members', icon: PERSON_2 },
  { value: props.totalGroups, label: 'Groups', icon: PERSON_3 },
  { value: props.totalEnrolledLessons, label: 'Enrolled Lessons', icon: BOOK },
  { value: props.totalStudies, label: 'Studies', icon: BOOK_CLOSED },
]

// VerticalBarChart wants {label,value,color}; brandPrimary bars like iOS.
const barPoints = props.weeklyActivity.map((p) => ({
  label: p.label,
  value: p.value,
  color: 'rgba(108,71,255,1)',
}))

// iOS MainHome maps each bucket to HeatMapDataPoint(week: day-of-week, day:
// hour-of-day) — so the X-axis is the 7 weekdays and the Y-axis is the 24 hours.
// Mirror that exactly: week ← day, day ← hour.
const heatPoints = props.heatmap.map((p) => ({ week: p.day, day: p.hour, value: p.value }))

// iOS passes these to HeatMapChart (xLabels = weekdays on X, yLabels = hours on
// Y) with showDayLabels:false and a tall 576pt chart.
const HEATMAP_X_LABELS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
const HEATMAP_Y_LABELS = [
  '12a', '1a', '2a', '3a', '4a', '5a', '6a', '7a', '8a', '9a', '10a', '11a',
  '12p', '1p', '2p', '3p', '4p', '5p', '6p', '7p', '8p', '9p', '10p', '11p',
]
</script>

<template>
  <div class="HomeDashboard">
    <!-- iOS status bar (62pt top safe-area inset). pages.home renders the full
         MainView, whose capture includes the device status bar; reproducing it
         keeps the PageHeader / KPI / heatmap-cutoff aligned with the iPhone. -->
    <div class="HomeDashboard__statusbar" aria-hidden="true">
      <span class="HomeDashboard__clock">9:41</span>
      <span class="HomeDashboard__indicators">
        <svg class="HomeDashboard__statusIcon" width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" />
          <rect x="5" y="5.5" width="3" height="6.5" rx="1" />
          <rect x="10" y="3" width="3" height="9" rx="1" />
          <rect x="15" y="0" width="3" height="12" rx="1" />
        </svg>
        <svg class="HomeDashboard__statusIcon" width="17" height="12" viewBox="0 0 17 12" fill="currentColor">
          <path d="M8.5 2C5.6 2 3 3.1 1 4.9l1.4 1.5C4 4.9 6.1 4 8.5 4s4.5.9 6.1 2.4L16 4.9C14 3.1 11.4 2 8.5 2z" />
          <path d="M8.5 6.2c-1.6 0-3 .6-4.1 1.6l1.5 1.5c.7-.6 1.6-1 2.6-1s1.9.4 2.6 1l1.5-1.5C11.5 6.8 10.1 6.2 8.5 6.2z" />
          <circle cx="8.5" cy="11" r="1.3" />
        </svg>
        <svg class="HomeDashboard__statusIcon HomeDashboard__battery" width="25" height="12" viewBox="0 0 25 12" fill="none">
          <rect x="0.5" y="0.5" width="21" height="11" rx="3" stroke="currentColor" stroke-opacity="0.4" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <path d="M23 4v4c.8-.3 1.3-1 1.3-2S23.8 4.3 23 4z" fill="currentColor" fill-opacity="0.4" />
        </svg>
      </span>
    </div>

    <!-- PageHeader (Home/Activity tabs) + the trailing add button. The button is
         MainHome page chrome (PageHeader's trailing ViewBuilder), not part of the
         shared PageHeader twin, so it lives here. -->
    <div class="HomeDashboard__headerRow">
      <PageHeader class="HomeDashboard__header" :tabs="['Home', 'Activity']" :active-tab="0" />
      <span class="HomeDashboard__addBtn" aria-hidden="true">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round">
          <path d="M12 5.5v13M5.5 12h13" />
        </svg>
      </span>
    </div>

    <div class="HomeDashboard__scroll">
      <!-- KPI grid (2×2) -->
      <div class="HomeDashboard__kpis">
        <Kpi
          v-for="k in kpis"
          :key="k.label"
          class="HomeDashboard__kpi"
          variant="iconValue"
          :kpi-value="k.value"
          value-type="number"
          :label="k.label"
          :icon="k.icon"
          :icon-color="KPI_ACCENT"
        />
      </div>

      <!-- Last 7 days -->
      <p class="HomeDashboard__section-label">Last 7 Days</p>
      <div class="HomeDashboard__chart">
        <VerticalBarChart :data-points="barPoints" :chart-height="160" />
      </div>

      <!-- Activity heatmap -->
      <p class="HomeDashboard__section-label">Activity Heatmap</p>
      <div class="HomeDashboard__chart">
        <HeatMapChart
          :data-points="heatPoints"
          :show-day-labels="false"
          :x-labels="HEATMAP_X_LABELS"
          :y-labels="HEATMAP_Y_LABELS"
          :chart-height="576"
        />
      </div>
    </div>

    <!-- NavBar floats over the scroll content; the wrapper carries the opaque
         appBackground fill (the NavBar's own bg is transparent) so the cut-off
         heatmap behind it is masked, like the iPhone MainView capture. -->
    <div class="HomeDashboard__nav">
      <NavBar active-tab="home" />
    </div>
  </div>
</template>
