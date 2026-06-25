<script setup lang="ts">
// SharedContentCard — invite domain. A card for a program/lesson shared with
// the user. Reuses a CardStudy-like visual (cover + title + ScopeBadge +
// "shared by {inviter}"). Data-driven; no store access.
//
// Interactive: role=button, emits `open`.
import ScopeBadge from '../scope-badge/scope-badge.vue'

type Role = 'member' | 'contributor'
type ScopeType = 'program' | 'lesson'

interface Props {
  title: string
  coverUrl?: string
  inviterName: string
  role: Role
  scopeType: ScopeType
  scopeLabel?: string
  class?: string
}

const props = defineProps<Props>()

const emit = defineEmits<{ open: [] }>()

const onClick = () => emit('open')

const onKeydown = (e: KeyboardEvent) => {
  if (e.key === 'Enter' || e.key === ' ') {
    e.preventDefault()
    emit('open')
  }
}
</script>

<template>
  <div
    :class="['SharedContentCard', props.class]"
    role="button"
    tabindex="0"
    @click="onClick"
    @keydown="onKeydown"
  >
    <div class="SharedContentCard__cover">
      <img
        v-if="coverUrl"
        class="SharedContentCard__image"
        :src="coverUrl"
        :alt="title"
      />
      <div v-else class="SharedContentCard__coverPlaceholder" aria-hidden="true"></div>
    </div>

    <div class="SharedContentCard__body">
      <ScopeBadge
        class="SharedContentCard__badge"
        :role="role"
        :scope-type="scopeType"
        :scope-label="scopeLabel"
      />
      <span class="SharedContentCard__title">{{ title }}</span>
      <span class="SharedContentCard__inviter">shared by {{ inviterName }}</span>
    </div>
  </div>
</template>
