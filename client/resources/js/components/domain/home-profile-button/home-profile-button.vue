<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'

interface Props {
  href: string
  loginHref: string
}

const props = defineProps<Props>()

const member = ref<Record<string, string> | null>(null)
const loaded = ref(false)

function navigateTo(url: string) {
  document.location.href = url
}

function formatPhone(phone: string): string {
  if (!phone) return ''
  const digits = phone.replace(/\D/g, '')
  const d = digits.startsWith('1') && digits.length === 11 ? digits.slice(1) : digits
  if (d.length === 10) {
    return `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`
  }
  return phone
}

const avatarSrc = computed(() =>
  member.value?.profilePicture || member.value?.avatarUrl || ''
)

const avatarClasses = computed(() => {
  if (!loaded.value) return 'Avatar Avatar--loading'
  if (avatarSrc.value) return 'Avatar Avatar--has-image'
  return 'Avatar'
})

const avatarStyle = computed(() => {
  if (loaded.value && avatarSrc.value) {
    return '--avatar-size: 36px; background-image: url(' + avatarSrc.value + ')'
  }
  return '--avatar-size: 36px'
})

const initials = computed(() => {
  if (!member.value) return ''
  return ((member.value.firstName || '?')[0] + (member.value.lastName || '')[0]).toUpperCase()
})

const buttonLabel = computed(() => {
  if (!member.value) return 'Member Login'
  return ((member.value.firstName || '') + ' ' + (member.value.lastName || '')).trim()
})

const buttonDescription = computed(() => {
  if (!member.value) return 'Sign in with your phone number'
  return formatPhone(member.value.phoneNumber || '')
})

const buttonHref = computed(() => {
  if (loaded.value && !member.value) return props.loginHref
  return props.href
})

onMounted(async () => {
  try {
    const csrfToken = document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content ?? ''
    const res = await fetch('/api/member-session', {
      headers: { 'Accept': 'application/json', 'X-CSRF-TOKEN': csrfToken },
    })
    if (res.ok) {
      const data = await res.json()
      if (data.authenticated && data.member) {
        member.value = data.member
      }
    }
  } catch {
    // Session expired or invalid — keep showing fallback
  } finally {
    loaded.value = true
  }
})
</script>

<template>
  <button
    type="button"
    class="Button Button--jump-primary"
    @click="navigateTo(buttonHref)"
  >
    <span class="Button__content">
      <div
        :class="avatarClasses"
        :style="avatarStyle"
        role="img"
      >
        <div v-if="!loaded" class="Avatar__spinner"></div>
        <div v-else-if="!avatarSrc && member" class="Avatar__fallback">{{ initials }}</div>
      </div>
      <span class="Button__details">
        <span class="Button__label">{{ buttonLabel }}</span>
        <span class="Button__description">{{ buttonDescription }}</span>
      </span>
      <span class="Button__icon Button__icon--right">
        <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/></svg>
      </span>
    </span>
  </button>
</template>
