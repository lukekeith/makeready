<script setup lang="ts">
import { ref } from 'vue'
import RoleSelector from './role-selector.vue'

const role = ref<'member' | 'contributor'>('member')
const contributor = ref<'member' | 'contributor'>('contributor')
const empty = ref<'member' | 'contributor' | undefined>(undefined)
</script>

<template>
  <Story title="Invite/RoleSelector" :layout="{ type: 'grid', width: 380 }">
    <Variant title="Member selected">
      <RoleSelector v-model="role" />
    </Variant>
    <Variant title="Contributor selected">
      <RoleSelector v-model="contributor" />
    </Variant>
    <Variant title="Nothing selected">
      <RoleSelector v-model="empty" />
    </Variant>
    <Variant title="Disabled">
      <RoleSelector :model-value="'contributor'" disabled />
    </Variant>
  </Story>
</template>
