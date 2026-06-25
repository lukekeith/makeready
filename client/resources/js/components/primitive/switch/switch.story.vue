<script setup lang="ts">
import { ref } from 'vue'
import Switch from './switch.vue'

const on = ref(true)
const off = ref(false)
</script>

<template>
  <Story title="Primitives/Switch" :layout="{ type: 'grid', width: 280 }">
    <Variant title="On">
      <Switch v-model="on" />
    </Variant>
    <Variant title="Off">
      <Switch v-model="off" />
    </Variant>
    <Variant title="Disabled (off)">
      <Switch :model-value="false" disabled />
    </Variant>
    <Variant title="Disabled (on)">
      <Switch :model-value="true" disabled />
    </Variant>
  </Story>
</template>
