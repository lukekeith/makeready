<script setup lang="ts">
import BarChart from './bar-chart.vue'
</script>

<template>
  <Story title="Data/BarChart" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Vertical — weekly activity">
      <BarChart
        :categories="['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']"
        :series="[{ name: 'Lessons', data: [12, 18, 9, 22, 14, 6, 3] }]"
      />
    </Variant>

    <Variant title="Vertical — multi-series">
      <BarChart
        :categories="['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4']"
        :series="[
          { name: 'Started', data: [30, 28, 35, 40] },
          { name: 'Completed', data: [18, 20, 26, 31] },
        ]"
      />
    </Variant>

    <Variant title="Horizontal — top groups">
      <BarChart
        horizontal
        :categories="['Genesis', 'Romans', 'John', 'Psalms', 'Acts']"
        :series="[{ name: 'Members', data: [27, 22, 19, 14, 9] }]"
      />
    </Variant>
  </Story>
</template>
