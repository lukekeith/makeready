<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import Menu from 'primevue/menu'
import Avatar from 'primevue/avatar'
import Divider from 'primevue/divider'

interface Props {
  avatarUrl?: string
  initials?: string
  memberName?: string
  logoutUrl?: string
}

const props = withDefaults(defineProps<Props>(), {
  initials: '?',
})

const route = useRoute()
const router = useRouter()
const userMenu = ref()

const navItems = computed(() => [
  {
    label: 'Navigation',
    items: [
      { label: 'Dashboard', icon: 'pi pi-objects-column', command: () => router.push('/admin'), class: route.path === '/admin' ? 'p-menuitem-active' : '' },
      { label: 'Groups', icon: 'pi pi-users', command: () => router.push('/admin/groups'), class: route.path.startsWith('/admin/groups') ? 'p-menuitem-active' : '' },
      { label: 'Members', icon: 'pi pi-id-card', command: () => router.push('/admin/members'), class: route.path.startsWith('/admin/members') ? 'p-menuitem-active' : '' },
      { label: 'Programs', icon: 'pi pi-book', command: () => router.push('/admin/programs'), class: route.path.startsWith('/admin/programs') ? 'p-menuitem-active' : '' },
      { label: 'Logs', icon: 'pi pi-list', command: () => router.push('/admin/logs'), class: route.path.startsWith('/admin/logs') ? 'p-menuitem-active' : '' },
      { label: 'Profile', icon: 'pi pi-user', command: () => router.push('/admin/profile'), class: route.path.startsWith('/admin/profile') ? 'p-menuitem-active' : '' },
    ],
  },
])

const userMenuItems = ref([
  { label: 'Member Experience', icon: 'pi pi-external-link', url: '/member/home' },
  { separator: true },
  { label: 'Logout', icon: 'pi pi-sign-out', command: handleLogout },
])

function toggleUserMenu(event: Event): void {
  userMenu.value.toggle(event)
}

function handleLogout() {
  if (!props.logoutUrl) return
  const form = document.createElement('form')
  form.method = 'POST'
  form.action = props.logoutUrl
  const token = document.createElement('input')
  token.type = 'hidden'
  token.name = '_token'
  token.value = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || ''
  form.appendChild(token)
  document.body.appendChild(form)
  form.submit()
}
</script>

<template>
  <aside style="width: 16rem; display: flex; flex-direction: column; border-right: 1px solid var(--p-content-border-color); background: var(--p-surface-0);">
    <!-- Logo -->
    <a href="/admin" style="display: flex; align-items: center; gap: 0.75rem; padding: 1rem 1.25rem; text-decoration: none; color: var(--p-text-color); font-weight: 600;">
      <img src="/logo-mark.svg" alt="MakeReady" style="width: 2rem; height: 2rem;" />
      <span>MakeReady</span>
    </a>

    <Divider style="margin: 0;" />

    <!-- Navigation -->
    <Menu :model="navItems" style="border: none; width: 100%; flex: 1;" />

    <Divider style="margin: 0;" />

    <!-- User Footer -->
    <div style="padding: 0.75rem 1rem;">
      <button
        style="display: flex; align-items: center; gap: 0.75rem; width: 100%; padding: 0.5rem; border: none; background: none; border-radius: var(--p-border-radius); cursor: pointer; color: var(--p-text-color);"
        @click="toggleUserMenu"
      >
        <Avatar
          v-if="avatarUrl"
          :image="avatarUrl"
          shape="circle"
        />
        <Avatar
          v-else
          :label="initials"
          shape="circle"
        />
        <span style="font-size: 0.875rem; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">{{ memberName }}</span>
      </button>
      <Menu ref="userMenu" :model="userMenuItems" :popup="true" />
    </div>
  </aside>
</template>
