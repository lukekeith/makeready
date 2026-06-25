<script setup lang="ts">
import { ref } from 'vue'
import TagInput from './tag-input.vue'

const empty = ref<string[]>([])
const filled = ref<string[]>(['faith', 'prayer', 'community'])
const capped = ref<string[]>(['one', 'two'])
const disabled = ref<string[]>(['locked', 'tags'])
</script>

<template>
  <Story title="Forms/TagInput" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Empty">
      <TagInput v-model="empty" placeholder="Add a tag…" />
    </Variant>

    <Variant title="Pre-filled">
      <TagInput v-model="filled" placeholder="Add a tag…" />
    </Variant>

    <Variant title="Max 3">
      <TagInput v-model="capped" :max="3" placeholder="Up to 3 tags" />
    </Variant>

    <Variant title="Disabled">
      <TagInput v-model="disabled" disabled placeholder="Add a tag…" />
    </Variant>
  </Story>
</template>
