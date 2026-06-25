<script setup lang="ts">
import { ref } from 'vue'
import SearchField from './search-field.vue'

const query = ref('Romans')
const empty = ref('')
</script>

<template>
  <Story title="Forms/SearchField" :layout="{ type: 'grid', width: 360 }">
    <Variant title="Default">
      <SearchField v-model="empty" />
    </Variant>

    <Variant title="Focus (n/a)">
      <SearchField v-model="empty" placeholder="Click to focus" />
    </Variant>

    <Variant title="Custom placeholder">
      <SearchField v-model="empty" placeholder="Search groups" />
    </Variant>

    <Variant title="Disabled">
      <SearchField disabled />
    </Variant>

    <Variant title="With value (clear shown)">
      <SearchField v-model="query" @clear="query = ''" />
    </Variant>
  </Story>
</template>
