<script setup lang="ts">
import { ref } from 'vue'
import Radio from './radio.vue'

const selected = ref('apple')
</script>

<template>
  <Story title="Primitives/Radio" :layout="{ type: 'grid', width: 280 }">
    <Variant title="Group">
      <div style="display: flex; flex-direction: column; gap: 12px">
        <Radio v-model="selected" value="apple" name="fruit">Apple</Radio>
        <Radio v-model="selected" value="banana" name="fruit">Banana</Radio>
        <Radio v-model="selected" value="cherry" name="fruit">Cherry</Radio>
      </div>
    </Variant>
    <Variant title="Checked">
      <Radio :model-value="'a'" value="a" name="r1">Selected</Radio>
    </Variant>
    <Variant title="Unchecked">
      <Radio :model-value="'a'" value="b" name="r2">Not selected</Radio>
    </Variant>
    <Variant title="Small">
      <Radio :model-value="'a'" value="a" size="Sm" name="r3">Small</Radio>
    </Variant>
    <Variant title="Disabled (unchecked)">
      <Radio :model-value="'a'" value="b" name="r4" disabled>Disabled</Radio>
    </Variant>
    <Variant title="Disabled (checked)">
      <Radio :model-value="'a'" value="a" name="r5" disabled>Disabled</Radio>
    </Variant>
  </Story>
</template>
