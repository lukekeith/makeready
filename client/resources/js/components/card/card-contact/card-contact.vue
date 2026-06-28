<script setup lang="ts">
// CardContact — list row for a device/org contact (iOS CardContact.swift parity).
//
// Layout mirrors iOS exactly: a horizontal row (8px spacing) of a 40×40 circular
// avatar, the contact's full name (17pt bold, single line), a flexible spacer,
// and an optional trailing "Invite" pill. Padding 16, cardBackground fill,
// 4px corners.
//
// Data fields (data-driven, no store access):
//   firstName   string   — required
//   lastName    string   — required
//   avatarUrl   string?   — circular avatar image; falls back to initials
//   showInvite  boolean  — render the trailing purple "Invite" ActionButton
//                          (iOS: the `invite` variant supplies this trailing content)
import { computed } from 'vue'
import Avatar from '../../primitive/avatar/avatar.vue'
import ActionButton from '../action-button/action-button.vue'

interface Props {
  firstName: string
  lastName: string
  avatarUrl?: string
  showInvite?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  avatarUrl: '',
  showInvite: false,
})

const emit = defineEmits<{ click: [MouseEvent]; invite: [MouseEvent] }>()

const fullName = computed(() => `${props.firstName} ${props.lastName}`)

// iOS: first letter of first + first letter of last, uppercased.
const initials = computed(
  () =>
    `${props.firstName.slice(0, 1)}${props.lastName.slice(0, 1)}`.toUpperCase()
)

const onClick = (e: MouseEvent) => emit('click', e)

const onInvite = (e: MouseEvent) => {
  // Trailing action shouldn't also fire the row tap.
  e.stopPropagation()
  emit('invite', e)
}

const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    emit('click', e as unknown as MouseEvent)
  }
}
</script>

<template>
  <div
    class="CardContact"
    :class="props.class"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <Avatar
      class="CardContact__avatar"
      :src="avatarUrl"
      :initials="initials"
      :alt="fullName"
    />

    <span class="CardContact__name">{{ fullName }}</span>

    <span class="CardContact__spacer" aria-hidden="true"></span>

    <div v-if="showInvite" class="CardContact__trailing">
      <ActionButton label="Invite" variant="purple" @click="onInvite" />
    </div>
  </div>
</template>
