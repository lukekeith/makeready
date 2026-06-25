<script setup lang="ts">
import DonutChart from './donut-chart.vue'
</script>

<template>
  <Story title="Data/DonutChart" :layout="{ type: 'grid', width: 420 }">
    <Variant title="Enrollment status">
      <DonutChart
        :series="[42, 18, 9]"
        :labels="['Active', 'Completed', 'Paused']"
        total="69"
      />
    </Variant>

    <Variant title="Activity mix (no center total)">
      <DonutChart
        :series="[120, 80, 60, 40, 25]"
        :labels="['Video', 'Reading', 'SOAP', 'Notes', 'Other']"
      />
    </Variant>
  </Story>
</template>
