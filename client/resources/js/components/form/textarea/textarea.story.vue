<script setup lang="ts">
import { ref } from 'vue'
import Textarea from './textarea.vue'

const note = ref('I am thankful for the time spent in study this morning. The passage reminded me to slow down and listen.')
const counted = ref('A short note')
</script>

<template>
  <Story title="Forms/Textarea" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default">
      <Textarea placeholder="Write your reflection..." />
    </Variant>

    <Variant title="Focus (n/a)">
      <Textarea placeholder="Click to focus" />
    </Variant>

    <Variant title="Error">
      <Textarea state="Error" model-value="This field needs attention." />
    </Variant>

    <Variant title="Success">
      <Textarea state="Success" model-value="Looks good." />
    </Variant>

    <Variant title="Disabled">
      <Textarea disabled placeholder="Disabled" />
    </Variant>

    <Variant title="With value (auto-grow)">
      <Textarea v-model="note" :max-rows="8" />
    </Variant>

    <Variant title="With character counter">
      <Textarea v-model="counted" :maxlength="120" placeholder="Max 120 characters" />
    </Variant>
  </Story>
</template>
