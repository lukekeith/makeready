<script setup lang="ts">
import '../../css/app.scss'

import DeviceFrame from '../components/layout/device-frame/device-frame.vue'
import AppShell from '../components/layout/app-shell/app-shell.vue'
import PageHeader from '../components/navigation/page-header/page-header.vue'
import Section from '../components/layout/section/section.vue'
import Grid from '../components/layout/grid/grid.vue'
import Kpi from '../components/data/kpi/kpi.vue'
import BarChart from '../components/data/bar-chart/bar-chart.vue'
import HeatMapChart from '../components/data/heatmap-chart/heatmap-chart.vue'
import CardActivity from '../components/card/card-activity/card-activity.vue'
import TabBar, { type TabBarTab } from '../components/navigation/tab-bar/tab-bar.vue'

// --- mock data ---------------------------------------------------------------
const kpis = [
  { value: 24, label: 'Members', trend: { dir: 'up', value: '+3' } as const },
  { value: 18, label: 'Active', trend: { dir: 'up', value: '+5' } as const },
  { value: '72%', label: 'Completion', trend: { dir: 'down', value: '-4%' } as const },
]

const weeklyActivity = {
  categories: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  series: [{ name: 'Activities', data: [12, 18, 9, 22, 16, 6, 14] }],
}

const heatmap = [
  { name: 'Week 1', data: [{ x: 'Mon', y: 2 }, { x: 'Tue', y: 4 }, { x: 'Wed', y: 1 }, { x: 'Thu', y: 5 }, { x: 'Fri', y: 3 }, { x: 'Sat', y: 0 }, { x: 'Sun', y: 2 }] },
  { name: 'Week 2', data: [{ x: 'Mon', y: 3 }, { x: 'Tue', y: 2 }, { x: 'Wed', y: 5 }, { x: 'Thu', y: 4 }, { x: 'Fri', y: 1 }, { x: 'Sat', y: 2 }, { x: 'Sun', y: 0 }] },
  { name: 'Week 3', data: [{ x: 'Mon', y: 1 }, { x: 'Tue', y: 5 }, { x: 'Wed', y: 4 }, { x: 'Thu', y: 3 }, { x: 'Fri', y: 5 }, { x: 'Sat', y: 1 }, { x: 'Sun', y: 3 }] },
  { name: 'Week 4', data: [{ x: 'Mon', y: 4 }, { x: 'Tue', y: 3 }, { x: 'Wed', y: 2 }, { x: 'Thu', y: 5 }, { x: 'Fri', y: 4 }, { x: 'Sat', y: 2 }, { x: 'Sun', y: 1 }] },
]

const checkIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>'
const userIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/></svg>'
const bookIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>'

const recentActivity = [
  { text: 'Maria Lopez completed Romans Day 12', timestamp: '12m ago', icon: checkIcon },
  { text: 'James Chen joined Young Professionals', timestamp: '1h ago', icon: userIcon },
  { text: 'New post in Sunday Morning group', timestamp: '3h ago', icon: bookIcon },
  { text: 'Aisha Patel completed Exodus Day 4', timestamp: '5h ago', icon: checkIcon },
  { text: 'David Kim joined College Ministry', timestamp: 'Yesterday', icon: userIcon },
]

const tabs: TabBarTab[] = [
  { key: 'home', label: 'Home' },
  { key: 'groups', label: 'Groups' },
  { key: 'library', label: 'Library' },
  { key: 'profile', label: 'Profile' },
]

// Lucide-style tab icons keyed by tab.key.
const tabIcons: Record<string, string> = {
  home: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/></svg>',
  groups: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
  library: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/></svg>',
  profile: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
}
</script>

<template>
  <Story title="Pages/Home Dashboard" group="pages" :layout="{ type: 'single' }">
    <Variant title="Dashboard">
      <DeviceFrame size="Md">
        <AppShell>
          <template #header>
            <PageHeader title="Home" />
          </template>

          <div class="HomeDashboard">
            <Section title="This week">
              <Grid cols="3" gap="Sm">
                <Kpi
                  v-for="kpi in kpis"
                  :key="kpi.label"
                  :value="kpi.value"
                  :label="kpi.label"
                  :trend="kpi.trend"
                />
              </Grid>
            </Section>

            <Section title="Weekly activity">
              <BarChart
                :categories="weeklyActivity.categories"
                :series="weeklyActivity.series"
                :height="200"
              />
            </Section>

            <Section title="Activity">
              <HeatMapChart :series="heatmap" :height="220" />
            </Section>

            <Section title="Recent activity">
              <CardActivity
                v-for="(item, i) in recentActivity"
                :key="i"
                :text="item.text"
                :timestamp="item.timestamp"
                :icon="item.icon"
              />
            </Section>
          </div>

          <template #tabbar>
            <TabBar :tabs="tabs" active="home">
              <template #icon="{ tab }">
                <span v-html="tabIcons[tab.key]" />
              </template>
            </TabBar>
          </template>
        </AppShell>
      </DeviceFrame>
    </Variant>
  </Story>
</template>

<style scoped>
.HomeDashboard {
  display: flex;
  flex-direction: column;
  gap: var(--space-6, 24px);
  padding: var(--space-4, 16px);
}
</style>
