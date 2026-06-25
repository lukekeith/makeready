<script setup lang="ts">
import { ref } from 'vue'
import Select from './select.vue'

const options = [
  { value: 'genesis', label: 'Genesis' },
  { value: 'exodus', label: 'Exodus' },
  { value: 'leviticus', label: 'Leviticus' },
  { value: 'numbers', label: 'Numbers' },
  { value: 'deuteronomy', label: 'Deuteronomy' },
]

const empty = ref('')
const selected = ref('exodus')
const openModel = ref('')
const multi = ref<string[]>(['genesis', 'numbers'])
const errored = ref('')
</script>

<template>
  <Story title="Forms/Select" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default (placeholder)">
      <Select v-model="empty" :options="options" placeholder="Select a book…" />
    </Variant>
    <Variant title="Selected">
      <Select v-model="selected" :options="options" />
    </Variant>
    <Variant title="Open">
      <Select v-model="openModel" :options="options" placeholder="Select a book…" />
    </Variant>
    <Variant title="Multiple">
      <Select v-model="multi" :options="options" multiple placeholder="Select books…" />
    </Variant>
    <Variant title="Error">
      <Select v-model="errored" :options="options" state="Error" placeholder="Required" />
    </Variant>
    <Variant title="Disabled">
      <Select :model-value="'exodus'" :options="options" disabled />
    </Variant>
  </Story>
</template>
