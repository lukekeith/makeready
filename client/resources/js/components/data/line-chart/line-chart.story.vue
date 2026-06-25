<script setup lang="ts">
import LineChart from './line-chart.vue'
</script>

<template>
  <Story title="Data/LineChart" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Single series — engagement">
      <LineChart
        :categories="['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4', 'Wk 5', 'Wk 6']"
        :series="[{ name: 'Active members', data: [12, 19, 17, 24, 28, 31] }]"
      />
    </Variant>

    <Variant title="Multi-series">
      <LineChart
        :categories="['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']"
        :series="[
          { name: 'Enrollments', data: [20, 32, 28, 45, 50, 62] },
          { name: 'Completions', data: [8, 14, 18, 22, 30, 41] },
        ]"
      />
    </Variant>
  </Story>
</template>
