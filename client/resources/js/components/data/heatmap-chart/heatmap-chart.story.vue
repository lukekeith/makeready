<script setup lang="ts">
import HeatMapChart from './heatmap-chart.vue'

// Day-of-week × hour-bucket activity. Each row is a weekday; each cell is a
// 3-hour bucket across the day.
const buckets = ['6a', '9a', '12p', '3p', '6p', '9p']
const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']

const series = days.map((name) => ({
  name,
  data: buckets.map((x) => ({ x, y: Math.floor(Math.random() * 40) })),
}))
</script>

<template>
  <Story title="Data/HeatMapChart" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Activity by day & hour">
      <HeatMapChart :series="series" />
    </Variant>
  </Story>
</template>
