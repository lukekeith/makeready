<script setup lang="ts">
import { ref } from 'vue'
import BulletTextInput from './bullet-text-input.vue'

const empty = ref('')
const withValue = ref('First item\nSecond item\nThird item')
</script>

<template>
  <Story title="Primitive/BulletTextInput" :layout="{ type: 'grid', width: 400 }">
    <Variant title="Default (empty)">
      <div style="background: #0d101a; padding: 16px; min-height: 120px;">
        <BulletTextInput v-model="empty" placeholder="Start typing..." />
      </div>
    </Variant>
    <Variant title="With Value">
      <div style="background: #0d101a; padding: 16px; min-height: 120px;">
        <BulletTextInput v-model="withValue" />
      </div>
    </Variant>
    <Variant title="Large">
      <div style="background: #0d101a; padding: 16px; min-height: 120px;">
        <BulletTextInput size="Large" v-model="empty" placeholder="Large size..." />
      </div>
    </Variant>
  </Story>
</template>
