<script setup lang="ts">
import { onMounted } from 'vue'
import { useAnalyticsUI } from '../stores/ui/analytics.ui'
import ApexChart from 'vue3-apexcharts'
import Card from 'primevue/card'
import Skeleton from 'primevue/skeleton'

const ui = useAnalyticsUI()
onMounted(() => { ui.loadDashboard() })
</script>

<template>
  <div style="display: flex; flex-direction: column; gap: 1.5rem;">
    <h1 style="font-size: 1.5rem; font-weight: 700; margin: 0;">Dashboard</h1>

    <!-- KPI Cards -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(14rem, 1fr)); gap: 1rem;">
      <Card>
        <template #content>
          <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
            <i class="pi pi-users" style="color: #8b5cf6;" />
            <span style="font-size: 0.875rem; color: var(--p-text-muted-color);">Groups</span>
          </div>
          <Skeleton v-if="ui.isLoading" height="2rem" width="4rem" />
          <div v-else style="font-size: 1.875rem; font-weight: 700;">{{ ui.totalGroups }}</div>
        </template>
      </Card>

      <Card>
        <template #content>
          <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
            <i class="pi pi-users" style="color: #0ea5e9;" />
            <span style="font-size: 0.875rem; color: var(--p-text-muted-color);">Total Members</span>
          </div>
          <Skeleton v-if="ui.isLoading" height="2rem" width="4rem" />
          <div v-else style="font-size: 1.875rem; font-weight: 700;">{{ ui.totalMembers }}</div>
        </template>
      </Card>

      <Card>
        <template #content>
          <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
            <i class="pi pi-chart-line" style="color: #16a34a;" />
            <span style="font-size: 0.875rem; color: var(--p-text-muted-color);">Active Enrollments</span>
          </div>
          <Skeleton v-if="ui.isLoading" height="2rem" width="4rem" />
          <div v-else style="font-size: 1.875rem; font-weight: 700;">{{ ui.activeEnrollments }}</div>
        </template>
      </Card>
    </div>

    <!-- Charts -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr)); gap: 1rem;">
      <Card>
        <template #title>Weekly Activity</template>
        <template #content>
          <Skeleton v-if="ui.isLoading" height="220px" />
          <ApexChart v-else-if="ui.weeklyChartSeries[0]?.data?.length" type="bar" :series="ui.weeklyChartSeries" :options="ui.weeklyChartOptions" height="220" />
          <div v-else style="display: flex; align-items: center; justify-content: center; height: 220px; color: var(--p-text-muted-color);">No activity data</div>
        </template>
      </Card>

      <Card>
        <template #title>Engagement by Day/Hour</template>
        <template #content>
          <Skeleton v-if="ui.isLoading" height="220px" />
          <ApexChart v-else-if="ui.heatmapSeries.length" type="heatmap" :series="ui.heatmapSeries" :options="ui.heatmapOptions" height="220" />
          <div v-else style="display: flex; align-items: center; justify-content: center; height: 220px; color: var(--p-text-muted-color);">No heatmap data</div>
        </template>
      </Card>
    </div>

    <!-- Upcoming Lessons -->
    <Card>
      <template #title><i class="pi pi-calendar" style="margin-right: 0.5rem;" />Upcoming Lessons</template>
      <template #content>
        <div v-if="ui.isCalendarLoading" style="display: flex; flex-direction: column; gap: 0.5rem;">
          <Skeleton v-for="i in 3" :key="i" height="2.5rem" />
        </div>
        <div v-else-if="ui.upcomingEvents.length === 0" style="color: var(--p-text-muted-color);">No upcoming lessons</div>
        <div v-else style="display: flex; flex-direction: column;">
          <div v-for="event in ui.upcomingEvents" :key="event.enrollmentId + event.date + event.title" style="display: flex; align-items: center; gap: 1rem; padding: 0.5rem 0; border-bottom: 1px solid var(--p-content-border-color);">
            <small style="color: var(--p-text-muted-color); width: 6rem; flex-shrink: 0;">{{ new Date(event.date).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }) }}</small>
            <span style="flex: 1; font-size: 0.875rem; font-weight: 500;">{{ event.title }}</span>
            <small style="color: var(--p-text-muted-color);">{{ event.groupName }}</small>
          </div>
        </div>
      </template>
    </Card>
  </div>
</template>
