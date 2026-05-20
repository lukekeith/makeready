<script setup lang="ts">
import { onMounted, provide } from 'vue'
import { RouterView } from 'vue-router'
import axios from 'axios'
import AdminSidebar from './components/admin-sidebar.vue'

interface Props {
  avatarUrl?: string
  initials?: string
  memberName?: string
  googleEmail?: string
  logoutUrl?: string
  memberId?: string
}

const props = withDefaults(defineProps<Props>(), {
  initials: '?',
})

provide('memberId', props.memberId)
provide('memberName', props.memberName)
provide('avatarUrl', props.avatarUrl)

onMounted(() => {
  const token = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content
  if (token) {
    axios.defaults.headers.common['X-CSRF-TOKEN'] = token
  }
})
</script>

<template>
  <div style="display: flex; min-height: 100vh;">
    <AdminSidebar
      :avatar-url="avatarUrl"
      :initials="initials"
      :member-name="memberName"
      :logout-url="logoutUrl"
    />
    <main style="flex: 1; padding: 1.5rem; overflow-y: auto; background: var(--p-surface-ground);">
      <RouterView />
    </main>
  </div>
</template>
