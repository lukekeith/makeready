<script setup lang="ts">
import { ref } from 'vue'
import AgeRangeInput from './age-range-input.vue'

const empty = ref<{ min: number | null; max: number | null }>({ min: null, max: null })
const range = ref<{ min: number | null; max: number | null }>({ min: 18, max: 35 })
const disabled = ref<{ min: number | null; max: number | null }>({ min: 13, max: 17 })
</script>

<template>
  <Story title="Forms/AgeRangeInput" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Empty">
      <AgeRangeInput v-model="empty" />
    </Variant>

    <Variant title="Set range">
      <AgeRangeInput v-model="range" />
    </Variant>

    <Variant title="Disabled">
      <AgeRangeInput v-model="disabled" disabled />
    </Variant>
  </Story>
</template>
