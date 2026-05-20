import { computed } from 'vue'
import { defineStore } from 'pinia'
import { useAnalyticsDomain } from '../domain/analytics.domain'
import { useGroupsDomain } from '../domain/groups.domain'

export const useAnalyticsUI = defineStore('analytics-ui', () => {
  const domain = useAnalyticsDomain()
  const groupsDomain = useGroupsDomain()

  // KPI computeds
  const totalGroups = computed(() => groupsDomain.groups.length)

  const totalMembers = computed(() =>
    groupsDomain.groups.reduce((sum, g) => sum + (g.memberCount ?? 0), 0)
  )

  const activeEnrollments = computed(() => domain.activeEnrollmentCount)

  const kpiCards = computed(() => [
    { label: 'Groups', value: totalGroups.value, icon: 'users' },
    { label: 'Total Members', value: totalMembers.value, icon: 'users' },
    { label: 'Active Enrollments', value: activeEnrollments.value, icon: 'trending-up' },
  ])

  // Heatmap series for ApexCharts type: 'heatmap' (day-of-week x hour)
  const heatmapSeries = computed(() => {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    return days.map((dayName, dayIdx) => ({
      name: dayName,
      data: Array.from({ length: 24 }, (_, hour) => {
        const bucket = domain.heatmapData.find(
          (b) => b.day === dayIdx && b.hour === hour
        )
        return { x: `${hour}:00`, y: bucket?.count ?? 0 }
      }),
    }))
  })

  const heatmapOptions = computed(() => ({
    chart: {
      type: 'heatmap' as const,
      background: 'transparent',
      toolbar: { show: false },
      animations: { enabled: false },
    },
    theme: { mode: 'dark' as const },
    dataLabels: { enabled: false },
    colors: ['#7c3aed'],
    plotOptions: {
      heatmap: {
        colorScale: {
          ranges: [
            { from: 0, to: 0, color: 'rgba(124,58,237,0.05)', name: 'None' },
            { from: 1, to: 5, color: 'rgba(124,58,237,0.3)', name: 'Low' },
            { from: 6, to: 20, color: 'rgba(124,58,237,0.6)', name: 'Medium' },
            { from: 21, to: 999, color: '#7c3aed', name: 'High' },
          ],
        },
      },
    },
    xaxis: {
      labels: {
        style: { colors: 'rgba(255,255,255,0.5)' },
        rotate: 0,
      },
    },
    yaxis: {
      labels: {
        style: { colors: 'rgba(255,255,255,0.5)' },
      },
    },
    tooltip: {
      theme: 'dark',
    },
    grid: {
      borderColor: 'rgba(255,255,255,0.05)',
    },
  }))

  // Weekly bar chart series for ApexCharts type: 'bar'
  const weeklyChartSeries = computed(() => [
    {
      name: 'Activity',
      data: domain.weeklyData.map((d) => d.count),
    },
  ])

  const weeklyChartOptions = computed(() => ({
    chart: {
      type: 'bar' as const,
      background: 'transparent',
      toolbar: { show: false },
      animations: { enabled: false },
    },
    theme: { mode: 'dark' as const },
    colors: ['#6c47ff'],
    plotOptions: {
      bar: {
        borderRadius: 4,
        columnWidth: '60%',
      },
    },
    dataLabels: { enabled: false },
    xaxis: {
      categories: domain.weeklyData.map((d) => d.date),
      labels: {
        style: { colors: 'rgba(255,255,255,0.5)' },
        rotate: -45,
      },
    },
    yaxis: {
      labels: {
        style: { colors: 'rgba(255,255,255,0.5)' },
      },
    },
    tooltip: {
      theme: 'dark',
    },
    grid: {
      borderColor: 'rgba(255,255,255,0.05)',
    },
  }))

  // First 20 upcoming calendar events
  const upcomingEvents = computed(() => domain.calendarEvents.slice(0, 20))

  const isLoading = computed(() => domain.isLoading)
  const isCalendarLoading = computed(() => domain.isCalendarLoading)

  async function loadDashboard(): Promise<void> {
    await groupsDomain.loadGroups()
    await domain.loadAll()
  }

  return {
    totalGroups,
    totalMembers,
    activeEnrollments,
    kpiCards,
    heatmapSeries,
    heatmapOptions,
    weeklyChartSeries,
    weeklyChartOptions,
    upcomingEvents,
    isLoading,
    isCalendarLoading,
    loadDashboard,
  }
})
