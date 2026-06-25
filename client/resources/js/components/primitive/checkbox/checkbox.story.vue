<script setup lang="ts">
import { ref } from 'vue'
import Checkbox from './checkbox.vue'

const checked = ref(true)
const unchecked = ref(false)
</script>

<template>
  <Story title="Primitives/Checkbox" :layout="{ type: 'grid', width: 280 }">
    <Variant title="Checked">
      <Checkbox v-model="checked">Remember me</Checkbox>
    </Variant>
    <Variant title="Unchecked">
      <Checkbox v-model="unchecked">Remember me</Checkbox>
    </Variant>
    <Variant title="Small">
      <Checkbox :model-value="true" size="Sm">Small</Checkbox>
    </Variant>
    <Variant title="No label">
      <Checkbox :model-value="true" />
    </Variant>
    <Variant title="Disabled (unchecked)">
      <Checkbox :model-value="false" disabled>Disabled</Checkbox>
    </Variant>
    <Variant title="Disabled (checked)">
      <Checkbox :model-value="true" disabled>Disabled</Checkbox>
    </Variant>
  </Story>
</template>
