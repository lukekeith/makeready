<script setup lang="ts">
// CardMember — member row (iOS CardMember.swift parity).
//
// A horizontal row (8px spacing): a 40×40 circular avatar on the left, a content
// column (name / metadata / group badges), a flexible spacer, and an optional
// trailing "Invite" pill. The whole row is the cardBackground well (radius 4,
// padding 16) and is interactive (role=button).
//
// Content column mirrors iOS exactly (VStack spacing 0):
//   • name      17pt bold, white, single line truncate
//   • metadata  label/value pairs (11px — label 50% white, value 70% white)
//   • groups    13pt medium, brand purple
// Both the metadata and groups rows carry iOS's 1px top inset.
//
// Data fields (data-driven, no store access):
//   firstName   string                       — required
//   lastName    string                       — required
//   avatarUrl   string?                      — circular avatar; falls back to initials
//   metadata    Array<{label, value}>        — labelValue metadata chips
//   groups      string[]                     — group name badges (brand purple)
//   showInvite  boolean                      — trailing purple "Invite" ActionButton
//                                              (iOS: the `invite` variant supplies it)
import { computed } from 'vue'
import Avatar from '../../primitive/avatar/avatar.vue'
import ActionButton from '../action-button/action-button.vue'

export interface CardMemberMetaItem {
  label: string
  value: string
}

interface Props {
  firstName: string
  lastName: string
  avatarUrl?: string
  metadata?: CardMemberMetaItem[]
  groups?: string[]
  showInvite?: boolean
  class?: string
}

const props = withDefaults(defineProps<Props>(), {
  avatarUrl: '',
  metadata: () => [],
  groups: () => [],
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
    class="CardMember"
    :class="props.class"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <Avatar
      class="CardMember__avatar"
      :src="avatarUrl || undefined"
      :initials="initials"
      :alt="fullName"
    />

    <div class="CardMember__body">
      <span class="CardMember__name">{{ fullName }}</span>

      <div v-if="metadata.length" class="CardMember__meta">
        <span
          v-for="(item, i) in metadata"
          :key="i"
          class="CardMember__metaItem"
        >
          <span class="CardMember__metaLabel">{{ item.label }}</span>
          <span class="CardMember__metaValue">{{ item.value }}</span>
        </span>
      </div>

      <div v-if="groups.length" class="CardMember__groups">
        <span
          v-for="(group, i) in groups"
          :key="i"
          class="CardMember__group"
          >{{ group }}</span
        >
      </div>
    </div>

    <span class="CardMember__spacer" aria-hidden="true"></span>

    <div v-if="showInvite" class="CardMember__trailing">
      <ActionButton label="Invite" variant="purple" @click="onInvite" />
    </div>
  </div>
</template>
