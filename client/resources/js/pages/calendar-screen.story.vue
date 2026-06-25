<script setup lang="ts">
import '../../css/app.scss'
import { ref } from 'vue'
import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import Calendar from '../components/data/calendar/calendar.vue'
import TabBar, { type TabBarTab } from '../components/navigation/tab-bar/tab-bar.vue'

// ── Mock data ────────────────────────────────────────────────────────────────
// June 2026, with a small spread of events and a pre-selected day showing its
// list. Month is hardcoded (0-indexed: 5 = June) — never new Date().
const month = ref({ year: 2026, month: 5 })
const selected = ref('2026-06-18')

const events = [
  { date: '2026-06-04', title: 'Romans • Day 4 discussion', time: '7:00 PM' },
  { date: '2026-06-11', title: 'Group prayer night', time: '6:30 PM' },
  { date: '2026-06-18', title: 'Midweek study: Romans 8', time: '7:00 PM' },
  { date: '2026-06-18', title: 'Leaders sync', time: '8:30 PM' },
  { date: '2026-06-25', title: 'Community dinner', time: '6:00 PM' },
]

const markedDates = ['2026-06-21']

const tabs: TabBarTab[] = [
  { key: 'home', label: 'Home' },
  { key: 'groups', label: 'Groups' },
  { key: 'library', label: 'Library' },
  { key: 'calendar', label: 'Calendar' },
  { key: 'search', label: 'Search' },
]
const activeTab = ref('calendar')

const icons: Record<string, string> = {
  home: '<path d="M3 10.5 12 3l9 7.5M5 9.5V21h5v-6h4v6h5V9.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  groups: '<path d="M16 19v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm13 10v-2a4 4 0 0 0-3-3.87M16 3.13A4 4 0 0 1 16 11" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  library: '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 19.5A2.5 2.5 0 0 0 6.5 22H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  calendar: '<path d="M8 2v4M16 2v4M3 10h18M5 4h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  search: '<path d="m21 21-4.3-4.3M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
}
</script>

<template>
  <Story title="Pages/Calendar" :layout="{ type: 'single' }">
    <DeviceFrame size="Md">
      <div class="CalendarScreen">
        <PageHeader title="Calendar" />

        <div class="CalendarScreen__body">
          <Calendar
            v-model:month="month"
            :selected="selected"
            :events="events"
            :marked-dates="markedDates"
            @select="(iso) => (selected = iso)"
          />
        </div>

        <TabBar v-model="activeTab" :tabs="tabs" class="CalendarScreen__tabs">
          <template #icon="{ tab }">
            <svg viewBox="0 0 24 24" v-html="icons[tab.key]" />
          </template>
        </TabBar>
      </div>
    </DeviceFrame>
  </Story>
</template>

<style scoped>
.CalendarScreen {
  display: flex;
  flex-direction: column;
  min-height: 100%;
  background: var(--bg-canvas);
}
.CalendarScreen__body {
  flex: 1;
  padding: var(--space-md);
  overflow-y: auto;
}
.CalendarScreen__tabs {
  margin-top: auto;
}
</style>
